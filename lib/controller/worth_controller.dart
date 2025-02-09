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
    final worths = {};
    for (final user in users)
      worths[user.username] = await user.netWorth(context);
    return Response.ok(worths);
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
    final netWorth = await user.netWorth(context);

    return Response.ok(netWorth);
  }
}
