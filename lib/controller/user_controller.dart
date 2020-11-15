import '../model/user.dart';
import '../gpagame.dart';

class UserController extends ResourceController {
  UserController(this.context, this.authServer);

  final ManagedContext context;
  final AuthServer authServer;

  @Operation.get()
  Future<Response> getAll() async {
    final query = Query<User>(context)
      ..join(set: (u) => u.investments);
    final users = await query.fetch();
    return Response.ok(users);
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

    if (request.authorization.ownerID != user.id) {
      // Filter out stuff for non-owner of user
    }

    return Response.ok(user);
  }

  // Disabled, do we even need ths?
  // @Operation.put("username")
  Future<Response> updateUser(
      @Bind.path("username") String username, @Bind.body() User user) async {
    final query = Query<User>(context)..where((o) => o.username).equalTo(username);
    final user = await query.fetchOne();

    if (user == null) {
      return Response.notFound();
    }

    if (request.authorization.ownerID != user.id) {
      return Response.unauthorized();
    }

    final updateQuery = Query<User>(context)
      ..values = user
      ..where((o) => o.id).equalTo(user.id);

    final updatedUser = await updateQuery.updateOne();
    if (updatedUser == null) {
      return Response.notFound();
    }

    return Response.ok(updatedUser);
  }

  // Disabled
  // @Operation.delete("username")
  Future<Response> deleteUser(@Bind.path("username") String username) async {
    final query = Query<User>(context)..where((o) => o.username).equalTo(username);
    final user = await query.fetchOne();

    if (request.authorization.ownerID != user.id) {
      return Response.unauthorized();
    }

    final deleteQuery = Query<User>(context)..where((o) => o.id).equalTo(user.id);
    await authServer.revokeAllGrantsForResourceOwner(user.id);
    await deleteQuery.delete();

    return Response.ok(null);
  }
}
