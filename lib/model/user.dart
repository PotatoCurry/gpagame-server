import 'package:gpagame/model/historical_stock_price.dart';
import 'package:gpagame/model/investment.dart';
import 'package:skyscrapeapi/sky_core.dart';

import '../gpagame.dart';

class User extends ManagedObject<_User>
    implements _User, ManagedAuthResourceOwner<_User> {
  @Serialize(output: false)
  String password;

  Future<double> netWorth(ManagedContext context) async {
    final query = Query<Investment>(context)
      ..where((i) => i.investor.id).equalTo(id)
      ..join(object: (i) => i.targetUser);
    final sum = await query.reduce.sum((i) => i.shareCount * i.targetUser.stockPrice);
    print(sum);
    return sum;
  }

  int totalShares(ManagedContext context, User user) {
    final investmentsInUser = investments.where((i) => i.targetUser == user);
    return investmentsInUser.fold(0, (sum, i) => sum + i.shareCount);
  }
}

class _User extends ResourceOwnerTableDefinition {
  // Skyward credentials
  @Column(omitByDefault: true)
  String skywardUsername;

  // TODO: Encrypt with the encrypt package
  @Column(omitByDefault: true)
  String skywardPassword;

  @Column(defaultValue: "false")
  bool initialized;

  @Column(defaultValue: "false")
  bool badCredentials;

  // Saved Skyward information, null until initialized
  @Column(nullable: true)
  String name;

  @Column(nullable: true)
  String schoolName;

  @Column(nullable: true)
  int grade;

  @Column(nullable: true)
  String imageURL;

  // Game mechanics

  @Column(defaultValue: "80.0")
  double stockPrice;

  DateTime lastUpdated;

  @Column(defaultValue: "10000.0")
  double availableFunds;

  ManagedSet<Investment> investments;

  ManagedSet<Investment> investors;

  ManagedSet<HistoricalStockPrice> historicalStockPrices;

  ManagedSet<HistoricalStockPrice> historicalNetWorths;
}
