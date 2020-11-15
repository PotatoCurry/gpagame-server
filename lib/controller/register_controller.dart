import '../gpagame.dart';
import '../model/user.dart';

class RegisterController extends ResourceController {
  RegisterController(this.context, this.authServer);

  final ManagedContext context;
  final AuthServer authServer;

  @Operation.post()
  Future<Response> createUser(@Bind.body() User user) async {
    // Check for required parameters before we spend time hashing
    // TODO: Check for other required values
    if (user.username == null || user.password == null || user.skywardUsername == null || user.skywardPassword == null)
      return Response.badRequest(
          body: {"error": "username, password, skywardUsername, and skywardPassword required."});

    user
      ..salt = AuthUtility.generateRandomSalt()
      ..hashedPassword = authServer.hashPassword(user.password, user.salt)
      ..lastUpdated = DateTime.now();
    final query = Query<User>(context)..values = user;

    final u = await query.insert();
    final token = await authServer.authenticate(
        user.username,
        user.password,
        request.authorization.credentials.username,
        request.authorization.credentials.password);

    final response = AuthController.tokenResponse(token);
    final newBody = u.asMap()..["authorization"] = response.body;
    return response..body = newBody;
  }

  @override
  Map<String, APIResponse> documentOperationResponses(
    APIDocumentContext context, Operation operation) {
    return {
      "200": APIResponse.schema("User successfully registered.", context.schema.getObject("UserRegistration")),
      "400": APIResponse.schema("Error response", APISchemaObject.freeForm())
    };
  }

  @override
  void documentComponents(APIDocumentContext context) {
    super.documentComponents(context);

    final userSchemaRef = context.schema.getObjectWithType(User);
    final userRegistration = APISchemaObject.object({
      "authorization": APISchemaObject.object({
        "access_token": APISchemaObject.string(),
        "token_type": APISchemaObject.string(),
        "expires_in": APISchemaObject.integer(),
        "refresh_token": APISchemaObject.string(),
        "scope": APISchemaObject.string()
      })
    });

    context.schema.register("UserRegistration", userRegistration);

    context.defer(() {
      final userSchema = context.document.components.resolve(userSchemaRef);
      userRegistration.properties.addAll(userSchema.properties);
    });
  }
}
