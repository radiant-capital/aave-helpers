// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool, ILendingPoolConfigurator, IAaveOracle} from 'aave-address-book/AaveV2.sol';
import {IV2RateStrategyFactory} from './IV2RateStrategyFactory.sol';

/// @dev Examples here assume the usage of the `AaveV2Payload` base contracts
/// contained in this same repository
interface IAaveV2ConfigEngine {
  struct Basic {
    string assetSymbol;
    string assetName;
    TokenImplementations implementations;
  }

  struct EngineLibraries {
    address listingEngine;
    address borrowEngine;
    address collateralEngine;
    address priceFeedEngine;
    address rateEngine;
  }

  struct EngineConstants {
    ILendingPool pool;
    ILendingPoolConfigurator poolConfigurator;
    IV2RateStrategyFactory ratesStrategyFactory;
    IAaveOracle oracle;
    address rewardsController;
    address collector;
  }

  /**
   * @dev Example (mock):
   * PoolContext({
   *   networkName: 'Polygon',
   *   networkAbbreviation: 'Pol'
   * })
   */
  struct PoolContext {
    string networkName;
    string networkAbbreviation;
  }

  /**
   * @dev Example (mock):
   * ListingV2({
   *   asset: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
   *   assetSymbol: 'AAVE',
   *   assetName: 'Aave Token',
   *   priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,
   *   rateStrategyParams: Rates.RateStrategyParams({
   *     optimalUsageRatio: _bpsToRay(80_00),
   *     baseVariableBorrowRate: _bpsToRay(25), // 0.25%
   *     variableRateSlope1: _bpsToRay(3_00),
   *     variableRateSlope2: _bpsToRay(75_00),
   *     stableRateSlope1: _bpsToRay(3_00),
   *     stableRateSlope2: _bpsToRay(75_00)
   *   }),
   *   enabledToBorrow: EngineFlags.ENABLED,
   *   flashloanable: EngineFlags.ENABLED,
   *   stableRateModeEnabled: EngineFlags.DISABLED,
   *   ltv: 70_50, // 70.5%
   *   liqThreshold: 76_00, // 76%
   *   liqBonus: 5_00, // 5%
   *   reserveFactor: 10_00, // 10%
   *   liqProtocolFee: 10_00, // 10%
   * }
   */
  struct ListingV2 {
    address asset;
    string assetSymbol;
    string assetName;
    address priceFeed;
    IV2RateStrategyFactory.RateStrategyParams rateStrategyParams; // Mandatory, no matter if enabled for borrowing or not
    uint256 enabledToBorrow;
    uint256 stableRateModeEnabled; // Only considered is enabledToBorrow == EngineFlags.ENABLED (true)
    uint256 ltv; // Only considered if liqThreshold > 0
    uint256 liqThreshold; // If `0`, the asset will not be enabled as collateral
    uint256 liqBonus; // Only considered if liqThreshold > 0
    uint256 reserveFactor; // Only considered if enabledToBorrow == EngineFlags.ENABLED (true)
    uint256 liqProtocolFee; // Only considered if liqThreshold > 0
  }

  struct RepackedListings {
    address[] ids;
    Basic[] basics;
    BorrowUpdate[] borrowsUpdates;
    CollateralUpdate[] collateralsUpdates;
    PriceFeedUpdate[] priceFeedsUpdates;
    IV2RateStrategyFactory.RateStrategyParams[] rates;
  }

  struct TokenImplementations {
    address aToken;
    address vToken;
    address sToken;
  }

  struct ListingWithCustomImpl {
    ListingV2 base;
    TokenImplementations implementations;
  }

  /**
   * @dev Example (mock):
   * BorrowUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   enabledToBorrow: EngineFlags.ENABLED,
   *   stableRateModeEnabled: EngineFlags.KEEP_CURRENT,
   *   reserveFactor: 15_00, // 15%
   * })
   */
  struct BorrowUpdate {
    address asset;
    uint256 enabledToBorrow;
    uint256 stableRateModeEnabled;
    uint256 reserveFactor;
  }

  /**
   * @dev Example (mock):
   * CollateralUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   ltv: 60_00,
   *   liqThreshold: 70_00,
   *   liqBonus: EngineFlags.KEEP_CURRENT,
   * })
   */
  struct CollateralUpdate {
    address asset;
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
  }

  /**
   * @dev Example (mock):
   * PriceFeedUpdate({
   *   asset: AaveV2EthereumAssets.AAVE_UNDERLYING,
   *   priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9
   * })
   */
  struct PriceFeedUpdate {
    address asset;
    address priceFeed;
  }

  /**
   * @dev Example (mock):
   * RateStrategyUpdate({
   *   asset: AaveV2EthereumAssets.AAVE_UNDERLYING,
   *   params: IV2RateStrategyFactory.RateStrategyParams({
   *     optimalUtilizationRate: _bpsToRay(80_00),
   *     baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
   *     variableRateSlope1: EngineFlags.KEEP_CURRENT,
   *     variableRateSlope2: _bpsToRay(75_00),
   *     stableRateSlope1: EngineFlags.KEEP_CURRENT,
   *     stableRateSlope2: _bpsToRay(75_00),
   *   })
   * })
   */
  struct RateStrategyUpdate {
    address asset;
    IV2RateStrategyFactory.RateStrategyParams params;
  }

  /**
   * @notice Performs full listing of the assets, in the Aave pool configured in this engine instance
   * @param context `PoolContext` struct, effectively meta-data for naming of a/v/s tokens.
   *   More information on the documentation of the struct.
   * @param listings `Listing[]` list of declarative configs for every aspect of the asset listings.
   *   More information on the documentation of the struct.
   */
  function listAssets(PoolContext memory context, ListingV2[] memory listings) external;

  /**
   * @notice Performs full listings of assets, in the Aave pool configured in this engine instance
   * @dev This function allows more customization, especifically enables to set custom implementations
   *   for a/v/s tokens.
   *   IMPORTANT. Use it only if understanding the internals of the Aave v2 protocol
   * @param context `PoolContext` struct, effectively meta-data for naming of a/v/s tokens.
   *   More information on the documentation of the struct.
   * @param listings `ListingWithCustomImpl[]` list of declarative configs for every aspect of the asset listings.
   */
  function listAssetsCustom(
    PoolContext memory context,
    ListingWithCustomImpl[] memory listings
  ) external;

  /**
   * @notice Performs an update on the rate strategy params of the assets, in the Aave pool configured in this engine instance
   * @dev The engine itself manages if a new rate strategy needs to be deployed or if an existing one can be re-used
   * @param updates `RateStrategyUpdate[]` list of declarative updates containing the new rate strategy params
   *   More information on the documentation of the struct.
   */
  function updateRateStrategies(RateStrategyUpdate[] memory updates) external;

  function RATE_STRATEGY_FACTORY() external view returns (IV2RateStrategyFactory);

  function POOL() external view returns (ILendingPool);

  function POOL_CONFIGURATOR() external view returns (ILendingPoolConfigurator);

  function ORACLE() external view returns (IAaveOracle);

  function ATOKEN_IMPL() external view returns (address);

  function VTOKEN_IMPL() external view returns (address);

  function STOKEN_IMPL() external view returns (address);

  function REWARDS_CONTROLLER() external view returns (address);

  function COLLECTOR() external view returns (address);

  function BORROW_ENGINE() external view returns (address);

  function COLLATERAL_ENGINE() external view returns (address);

  function LISTING_ENGINE() external view returns (address);

  function PRICE_FEED_ENGINE() external view returns (address);

  function RATE_ENGINE() external view returns (address);
}
