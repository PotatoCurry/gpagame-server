import 'package:gpagame/model/user.dart';

import '../gpagame.dart';

class HistoricalStockPrice extends ManagedObject<_HistoricalStockPrice>
    implements _HistoricalStockPrice {}

class _HistoricalStockPrice {
  @primaryKey
  int id;

  double stockPrice;

  DateTime time;

  @Relate(#historicalStockPrices)
  User user;
}
