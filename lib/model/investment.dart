import 'package:gpagame/model/user.dart';

import '../gpagame.dart';

class Investment extends ManagedObject<_Investment> implements _Investment {
  double get originalWorth => shareCount * stockPriceWhenBought;
}

class _Investment {
  @primaryKey
  int id;

  int shareCount;

  double stockPriceWhenBought;

  @Relate(#investments)
  User investor;

  @Relate(#investors)
  User targetUser;
}
