abstract final class AppBreakpoints {
  static const double phoneMax = 599;
  static const double tabletMax = 1023;

  static bool isPhone(double width) => width <= phoneMax;

  static bool isTablet(double width) =>
      width > phoneMax && width <= tabletMax;

  static bool isDesktop(double width) => width > tabletMax;
}
