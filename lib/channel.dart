import 'dart:convert';

import 'package:gpagame/controller/historical_price_controller.dart';
import 'package:gpagame/controller/trade_controller.dart';
import 'package:gpagame/controller/worth_controller.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'controller/identity_controller.dart';
import 'controller/register_controller.dart';
import 'controller/user_controller.dart';
import 'gpagame.dart';
import 'model/user.dart' as site_model;
import 'skyward.dart';
import 'utility/html_template.dart';

final log = Logger('gpagame');

/// This type initializes an application.
///
/// Override methods in this class to set up routes and initialize services like
/// database connections. See http://aqueduct.io/docs/http/channel/.
class GpagameChannel extends ApplicationChannel
    implements AuthRedirectControllerDelegate {
  final HTMLRenderer htmlRenderer = HTMLRenderer();
  final Map<int, WebSocket> connections = {};
  AuthServer authServer;
  ManagedContext context;

  /// Run application setup tasks
  // static Future initializeApplication(ApplicationOptions options) async {
  //   log.level = Level.ALL;
  //   log.onRecord.listen(
  //           (rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));
  //
  //   final config = GpagameConfiguration(options.configurationFilePath);
  //   final context = contextWithConnectionInfo(config.database);
  // }

  /// Initialize services in this method.
  ///
  /// Implement this method to initialize services, read values from [options]
  /// and any other initialization required before constructing [entryPoint].
  ///
  /// This method is invoked prior to [entryPoint] being accessed.
  @override
  Future prepare() async {
    hierarchicalLoggingEnabled = true;
    log.level = Level.ALL;
    logger.onRecord.listen(
        (rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));

    final config = GpagameConfiguration(options.configurationFilePath);
    context = contextWithConnectionInfo(config.database);
    final authStorage = ManagedAuthDelegate<site_model.User>(context);
    authServer = AuthServer(authStorage);

    Timer.periodic(const Duration(days: 1), (timer) => updateStockPrices(context));
  }

  /// Construct the request channel.
  ///
  /// Return an instance of some [Controller] that will be the initial receiver
  /// of all [Request]s.
  ///
  /// This method is invoked after [prepare].
  @override
  Controller get entryPoint {
    final router = Router();

    /* OAuth 2.0 Endpoints */
    router.route("/auth/token").link(() => AuthController(authServer));

    router
        .route("/auth/form")
        .link(() => AuthRedirectController(authServer, delegate: this));

    /* Create an account */
    router
        .route("/register")
        .link(() => Authorizer.basic(authServer))
        .link(() => RegisterController(context, authServer));

    /* See account creation progress */
    router
        .route("/register/status")
        .linkFunction((request) async {
          // Prematurely closes websocket
          // ignore: close_sinks
          final socket = await WebSocketTransformer.upgrade(request.raw);
          final payload = await socket.first;
          final incoming = json.decode(payload as String);
          final username = incoming["username"] as String;
          final query = Query<site_model.User>(context)
            ..where((u) => u.username).equalTo(username)
            ..returningProperties((user) => [user.skywardUsername, user.skywardPassword, user.badCredentials]);
          final user = await query.fetchOne();

          initializeAccount(username, context).listen((status) async {
            connections[user.id] = socket;
            String outgoing;
            if (status == null)
              outgoing = json.encode({"status": "error"});
            else
              outgoing = json.encode({"status": status});
            socket.add(outgoing);
          });
          return null;
        });

    /* Gets profile for user with bearer token */
    router
        .route("/me")
        .link(() => Authorizer.bearer(authServer))
        .link(() => IdentityController(context));

    /* Gets all users or a specific user by name */
    router
        .route("/users/[:username]")

        .link(() => Authorizer.bearer(authServer))
        .link(() => UserController(context, authServer));

    /* Gets previous trades or execute new ones */
    router
        .route("/trades/[:username]")
        .link(() => Authorizer.bearer(authServer))
        .link(() => TradeController(context));

    /* Gets historical stock prices for a user */
    router
        .route("/history/[:username]")
        .link(() => Authorizer.bearer(authServer))
        .link(() => HistoricalPriceController(context));

    /* Gets historical stock prices for a user */
    router
        .route("/worth/[:username]")
        .link(() => Authorizer.bearer(authServer))
        .link(() => WorthController(context));

    return router;
  }

  // Helper methods

  static ManagedContext contextWithConnectionInfo(
      DatabaseConfiguration connectionInfo) {
    final dataModel = ManagedDataModel.fromCurrentMirrorSystem();
    final psc = PostgreSQLPersistentStore(
        connectionInfo.username,
        connectionInfo.password,
        connectionInfo.host,
        connectionInfo.port,
        connectionInfo.databaseName);

    return ManagedContext(dataModel, psc);
  }

  @override
  Future<String> render(AuthRedirectController forController, Uri requestUri,
      String responseType, String clientID, String state, String scope) async {
    final map = {
      "response_type": responseType,
      "client_id": clientID,
      "state": state
    };

    map["path"] = requestUri.path;
    if (scope != null) {
      map["scope"] = scope;
    }

    return htmlRenderer.renderHTML("web/login.html", map);
  }

  void handleEvent(dynamic event, User user) {

  }
}

/// An instance of this class represents values from a configuration
/// file specific to this application.
///
/// Configuration files must have key-value for the properties in this class.
/// For more documentation on configuration files, see
/// https://pub.dartlang.org/packages/safe_config.
class GpagameConfiguration extends Configuration {
  GpagameConfiguration(String fileName) : super.fromFile(File(fileName));

  DatabaseConfiguration database;
}
