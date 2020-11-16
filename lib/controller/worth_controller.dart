import '../model/user.dart';
import '../gpagame.dart';

class WorthController extends ResourceController {
  WorthController(this.context);

  final ManagedContext context;

  @Operation.get()
  Future<Response> getAll() async {
    final query = Query<User>(context)
      ..join(set: (u) => u.investments);
    final users = await query.fetch();
    final netWorths = users.map((u) => u.netWorth(context));
    return Response.ok(netWorths);
  }

  @Operation.get("username")
  Future<Response> getUser(@Bind.path("username") String username) async {
    final query = Query<User>(context)
      ..where((o) => o.username).equalTo(username)
      ..join(set: (u) => u.investments);
    final user = await query.fetchOne();
    if (user == null) {
      return Response.notFound();
    }
    final netWorth = user.netWorth(context);

    if (request.authorization.ownerID != user.id) {
      // Filter out stuff for non-owner of user
    }

    return Response.ok(netWorth);
  }
}
