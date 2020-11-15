import 'package:gpagame/model/investment.dart';

import '../gpagame.dart';
import '../model/user.dart';

class TradeController extends ResourceController {
  TradeController(this.context);

  final ManagedContext context;

  @Operation.get()
  Future<Response> getTrades() async {
    final query = Query<User>(context)
      ..where((o) => o.id).equalTo(request.authorization.ownerID);

    final user = await query.fetchOne();
    if (user == null) {
      return Response.notFound();
    }

    final investments = user.investments;
    return Response.ok(investments);
  }

  @Operation.get("username")
  Future<Response> getTradesForUser(
      @Bind.path("username") String username) async {
    final userQuery = Query<User>(context)
      ..where((u) => u.username).equalTo(username);

    final targetUser = await userQuery.fetchOne();
    if (targetUser == null) {
      return Response.notFound();
    }

    final investmentsQuery = Query<Investment>(context)
      ..where((i) => i.investor.id).equalTo(request.authorization.ownerID)
      ..where((i) => i.targetUser.username).equalTo(username);

    final investments = investmentsQuery.fetch();
    return Response.ok(investments);
  }

  @Operation.post("username")
  Future<Response> executeTrade(
      @Bind.path("username") String username,
      @Bind.query("action") String action,
      @Bind.query("amount") int shareCount) async {
    final investorQuery = Query<User>(context)
      ..where((o) => o.id).equalTo(request.authorization.ownerID);
    final targetQuery = Query<User>(context)
      ..where((o) => o.username).equalTo(username);
    final investor = await investorQuery.fetchOne();
    final targetUser = await targetQuery.fetchOne();

    if (targetUser == null)
      return Response.notFound();
    if (request.authorization.ownerID == targetUser.id)
      return Response.badRequest(body: {"error": "cannot invest in yourself."});
    if (shareCount <= 0)
      return Response.badRequest(body: {"error": "amount must be positive"});

    final liquidFunds = targetUser.stockPrice * shareCount;
    switch (action) {
      case "buy": {
        if (liquidFunds > investor.availableFunds)
          return Response(422, null, {"error": "not enough funds."});
        investor.availableFunds -= liquidFunds;
      }
      break;

      case "sell": {
        final investmentQuery = Query<Investment>(context)
          ..where((investment) => investment.targetUser.id).equalTo(targetUser.id);
        final totalShares = await investmentQuery.reduce
            .sum((investment) => investment.shareCount) ?? 0;
        if (shareCount > totalShares)
          return Response(422, null, {"error": "not enough shares."});
        investor.availableFunds += liquidFunds;
        // ignore: parameter_assignments
        shareCount = -shareCount;
      }
      break;

      default: {
        return Response.badRequest(
            body: {"error": "${action} is not a valid action."});
      }
    }

    final investment = Investment()
      ..shareCount = shareCount
      ..stockPriceWhenBought = targetUser.stockPrice
      ..investor = investor
      ..targetUser = targetUser;

    final withdrawQuery = Query<User>(context)
      ..values.availableFunds = investor.availableFunds
      ..where((o) => o.id).equalTo(investor.id);
    final investmentQuery = Query<Investment>(context)..values = investment;

    await withdrawQuery.update();
    final i = await investmentQuery.insert();

    return Response.ok(i);
  }
}
