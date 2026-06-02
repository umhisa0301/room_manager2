abstract final class ShopDiscoveryPoolFallbackConfig {
  static const bool kForceApiFailureForTest = bool.fromEnvironment(
    'SHOP_DISCOVERY_FORCE_API_FAILURE_FOR_TEST',
    defaultValue: false,
  );
}
