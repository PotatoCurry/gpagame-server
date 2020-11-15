import 'package:gpagame/model/historical_stock_price.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'gpagame.dart';
import 'model/user.dart' as site_model;

void updateStockPrices(ManagedContext context) async {
  final query = Query<site_model.User>(context)
    ..returningProperties((user) => [user.skywardUsername, user.skywardPassword, user.badCredentials]);
  final users = await query.fetch();

  for (final user in users) {
    try {
      final skywardUser = await SkyCore.login(user.skywardUsername, user.skywardPassword, "https://skyward-fbprod.iscorp.com/scripts/wsisa.dll/WService%3Dwsedufortbendtx/fwemnu01.w");
      final stockPrice = await calculateRoughAverage(skywardUser);
      await updateStockPrice(context, user, stockPrice);
      log.fine("Updated stock price for user ${user.id} to ${stockPrice}");
      if (user.badCredentials) {
        final badCredentialQuery = Query<site_model.User>(context)
          ..values.badCredentials = false
          ..where((u) => u.id).equalTo(user.id);
        await badCredentialQuery.updateOne();
        log.fine("Removed bad credentials mark on user ${user.id}");
      }
    } on SkywardError {
      log.warning("Could not update stock price for user ${user.id}");
      if (!user.badCredentials) {
        final badCredentialQuery = Query<site_model.User>(context)
          ..values.badCredentials = true
          ..where((u) => u.id).equalTo(user.id);
        await badCredentialQuery.updateOne();
        log.fine("Marked user ${user.id} as having bad credentials");
      }
    }
  }
}

Future<void> updateStockPrice(ManagedContext context, site_model.User user,
    double stockPrice) async {
  final historicalStockQuery = Query<HistoricalStockPrice>(context)
    ..values.stockPrice = stockPrice
    ..values.time = DateTime.now()
    ..values.user = user;
  await historicalStockQuery.insert();

  final stockQuery = Query<site_model.User>(context)
    ..values.stockPrice = stockPrice
    ..values.lastUpdated = DateTime.now()
    ..where((u) => u.id).equalTo(user.id);
  await stockQuery.updateOne();
}

Future<double> calculateRoughAverage(User skywardUser) async {
  final gradebook = await skywardUser.getGradebook();
  final assignments = gradebook.getAllAssignments()
      .where((a) => a.getDecimal() != null);

  final grades = assignments.map((a) => double.parse(a.getDecimal()));
  final average = grades.reduce((sum, g) => sum + g) / grades.length;
  return average;
}
