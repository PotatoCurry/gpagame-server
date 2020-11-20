import 'package:gpagame/model/historical_stock_price.dart';
import 'package:skyscrapeapi/sky_core.dart';

import 'gpagame.dart';
import 'model/user.dart' as site_model;

Stream<String> initializeAccount(String username, ManagedContext context) async* {
  final query = Query<site_model.User>(context)
    ..where((u) => u.username).equalTo(username)
    ..returningProperties((user) => [user.skywardUsername, user.skywardPassword, user.initialized, user.badCredentials]);
  var user = await query.fetchOne();
  try {
    if (user.initialized) {
      yield null;
      return;
    }
    yield "creating_account";

    final skywardUser = await SkyCore.login(user.skywardUsername, user.skywardPassword, "https://skyward-fbprod.iscorp.com/scripts/wsisa.dll/WService%3Dwsedufortbendtx/fwemnu01.w");
    yield "logging_into_skyward";
    log.fine("Logged into Skyward for user ${user.username}");

    final studentProfile = await skywardUser.getStudentProfile();
    yield "downloading_student_info";
    log.fine("Downloaded student info for user ${user.username}");

    final gradebook = await skywardUser.getGradebook();
    yield "accessing_gradebook";
    log.fine("Accessed gradebook for user ${user.username}");

    // TODO: Hold uninitialized profiles in a temporary table to avoid having nullable properties in the user table
    final studentQuery = Query<site_model.User>(context)
      ..values.initialized = true
      ..values.name = studentProfile.name
      ..values.schoolName = studentProfile.currentSchool.schoolName
      ..values.grade = int.parse(studentProfile.currentSchool.attributes["Grade:"])
      ..values.imageURL = studentProfile.studentAttributes["Student Image Href Link"]
      ..values.schedule = gradebook.getAllClasses()
          .map((course) => course.courseName).join(':::')
      ..where((u) => u.id).equalTo(user.id);
    user = await studentQuery.updateOne();

    final average = await calculateRoughAverage(skywardUser);
    await updateStockPrice(context, user, average);
    yield "calculating_stock_value";
    log.fine("Calculated stock value for user ${user.username}");
  } on SkywardError {
    yield "error_logging_in";
    log.warning("Error logging into Skyward for user ${user.username}");
    final badCredentialQuery = Query<site_model.User>(context)
      ..values.badCredentials = true
      ..where((u) => u.id).equalTo(user.id);
    await badCredentialQuery.updateOne();
  }
}

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
