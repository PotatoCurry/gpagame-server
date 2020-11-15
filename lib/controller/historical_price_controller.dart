import '../gpagame.dart';
import '../model/user.dart';

class HistoricalPriceController extends ResourceController {
  HistoricalPriceController(this.context);

  final ManagedContext context;

  @Operation.get()
  Future<Response> getHistoricalPrices() async {
    final query = Query<User>(context)
      ..where((u) => u.id).equalTo(request.authorization.ownerID)
      ..join(set: (u) => u.historicalStockPrices);

    final user = await query.fetchOne();
    if (user == null) {
      return Response.notFound();
    }

    final historicalPrices = user.historicalStockPrices;
    return Response.ok(historicalPrices);
  }

  @Operation.get("username")
  Future<Response> getHistoricalPricesForUser(
      @Bind.path("username") String username) async {
    final query = Query<User>(context)
      ..where((u) => u.username).equalTo(username)
      ..join(set: (u) => u.historicalStockPrices);

    final user = await query.fetchOne();
    if (user == null) {
      return Response.notFound();
    }

    final historicalPrices = user.historicalStockPrices;
    return Response.ok(historicalPrices);
  }
}
