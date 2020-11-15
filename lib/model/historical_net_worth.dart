import 'package:gpagame/model/user.dart';

import '../gpagame.dart';

class HistoricalNetWorth extends ManagedObject<_HistoricalNetWorth> implements _HistoricalNetWorth {}

class _HistoricalNetWorth {
  @primaryKey
  int id;

  double netWorth;

  @Relate(#historicalNetWorths)
  User user;
}
