// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ListingV2Engine as ListingEngine} from './libraries/ListingV2Engine.sol';
import {RateV2Engine as RatingEngine} from './libraries/RateV2Engine.sol';
import {EngineFlags} from '../v3-config-engine/EngineFlags.sol';
import './IAaveV2ConfigEngine.sol';

/**
 * @dev Helper smart contract abstracting the complexity of changing rates configurations on Aave v2.
 *      It is planned to be used via delegatecall, by any contract having appropriate permissions to update rates
 * IMPORTANT!!! This contract MUST BE STATELESS always, as in practise is a library to be used via DELEGATECALL
 * @author BGD Labs
 */
contract AaveV2ConfigEngine is IAaveV2ConfigEngine {
  struct AssetsConfig {
    address[] ids;
    IV2RateStrategyFactory.RateStrategyParams[] rates;
  }

  ILendingPool public immutable POOL;
  ILendingPoolConfigurator public immutable POOL_CONFIGURATOR;
  IV2RateStrategyFactory public immutable RATE_STRATEGIES_FACTORY;
  address public immutable ATOKEN_IMPL;
  address public immutable VTOKEN_IMPL;
  address public immutable STOKEN_IMPL;

  address public immutable BORROW_ENGINE;
  address public immutable COLLATERAL_ENGINE;
  address public immutable LISTING_ENGINE;
  address public immutable PRICE_FEED_ENGINE;
  address public immutable RATE_ENGINE;

  constructor(
    address aTokenImpl,
    address vTokenImpl,
    address sTokenImpl,
    EngineConstants memory engineConstants,
    EngineLibraries memory engineLibraries
  ) {
    require(
      address(engineConstants.pool) != address(0) &&
        address(engineConstants.poolConfigurator) != address(0) &&
        address(engineConstants.ratesStrategyFactory) != address(0) &&
        address(engineConstants.oracle) != address(0) &&
        engineConstants.rewardsController != address(0) &&
        engineConstants.collector != address(0),
      'ONLY_NONZERO_ENGINE_CONSTANTS'
    );

    require(
      aTokenImpl != address(0) && vTokenImpl != address(0) && sTokenImpl != address(0),
      'ONLY_NONZERO_TOKEN_IMPLS'
    );

    ATOKEN_IMPL = aTokenImpl;
    VTOKEN_IMPL = vTokenImpl;
    STOKEN_IMPL = sTokenImpl;
    POOL = engineConstants.pool;
    POOL_CONFIGURATOR = engineConstants.poolConfigurator;
    RATE_STRATEGIES_FACTORY = rateStrategiesFactory;
  }

  /// @inheritdoc IAaveV2ConfigEngine
  function listAssets(PoolContext calldata context, ListingV2[] calldata listings) external {
    require(listings.length != 0, 'AT_LEAST_ONE_ASSET_REQUIRED');

    ListingWithCustomImpl[] memory customListings = new ListingWithCustomImpl[](listings.length);
    for (uint256 i = 0; i < listings.length; i++) {
      customListings[i] = ListingWithCustomImpl({
        base: listings[i],
        implementations: TokenImplementations({
          aToken: ATOKEN_IMPL,
          vToken: VTOKEN_IMPL,
          sToken: STOKEN_IMPL
        })
      });
    }

    listAssetsCustom(context, customListings);
  }

  /// @inheritdoc IAaveV2ConfigEngine
  function listAssetsCustom(
    PoolContext calldata context,
    ListingWithCustomImpl[] memory listings
  ) public {
    LISTING_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        ListingEngine.executeCustomAssetListing.selector,
        context,
        _getEngineConstants(),
        _getEngineLibraries(),
        listings
      )
    );
  }

  /// @inheritdoc IAaveV2ConfigEngine
  function updateRateStrategies(RateStrategyUpdate[] memory updates) public {
    RATE_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        RateEngine.executeRateStrategiesUpdate.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  function _getEngineLibraries() internal view returns (EngineLibraries memory) {
    return
      EngineLibraries({
        listingEngine: LISTING_ENGINE,
        borrowEngine: BORROW_ENGINE,
        collateralEngine: COLLATERAL_ENGINE,
        priceFeedEngine: PRICE_FEED_ENGINE,
        rateEngine: RATE_ENGINE
      });
  }

  function _getEngineConstants() internal view returns (EngineConstants memory) {
    return
      EngineConstants({
        pool: POOL,
        poolConfigurator: POOL_CONFIGURATOR,
        ratesStrategyFactory: RATE_STRATEGY_FACTORY,
        oracle: ORACLE,
        rewardsController: REWARDS_CONTROLLER,
        collector: COLLECTOR
      });
  }
}
