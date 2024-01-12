// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20Metadata} from 'solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {IAaveV2ConfigEngine as IEngine, ILendingPoolConfigurator as IPoolConfigurator, IV2RateStrategyFactory, ILendingPool as IPool} from '../IAaveV2ConfigEngine.sol';
import {PriceFeedEngine} from '../../v3-config-engine/libraries/PriceFeedEngine.sol';
import {BorrowV2Engine as BorrowEngine} from './BorrowV2Engine.sol';
import {CollateralV2Engine as CollateralEngine} from './CollateralV2Engine.sol';
import {ConfiguratorInputTypes} from 'aave-address-book/AaveV2.sol';
import {Address} from 'solidity-utils/contracts/oz-common/Address.sol';

library ListingV2Engine {
  using Address for address;

  function executeCustomAssetListing(
    IEngine.PoolContext calldata context,
    IEngine.EngineConstants calldata engineConstants,
    IEngine.EngineLibraries calldata engineLibraries,
    IEngine.ListingWithCustomImpl[] calldata listings
  ) external {
    require(listings.length != 0, 'AT_LEAST_ONE_ASSET_REQUIRED');

    IEngine.RepackedListings memory repacked = _repackListing(listings);

    engineLibraries.priceFeedEngine.functionDelegateCall(
      abi.encodeWithSelector(
        PriceFeedEngine.executePriceFeedsUpdate.selector,
        engineConstants,
        repacked.priceFeedsUpdates
      )
    );

    _initAssets(
      context,
      engineConstants.poolConfigurator,
      engineConstants.ratesStrategyFactory,
      engineConstants.collector,
      engineConstants.rewardsController,
      repacked.ids,
      repacked.basics,
      repacked.rates
    );

    engineLibraries.borrowEngine.functionDelegateCall(
      abi.encodeWithSelector(
        BorrowEngine.executeBorrowSide.selector,
        engineConstants,
        repacked.borrowsUpdates
      )
    );

    engineLibraries.collateralEngine.functionDelegateCall(
      abi.encodeWithSelector(
        CollateralEngine.executeCollateralSide.selector,
        engineConstants,
        repacked.collateralsUpdates
      )
    );
  }

  function _repackListing(
    IEngine.ListingWithCustomImpl[] calldata listings
  ) internal pure returns (IEngine.RepackedListings memory) {
    address[] memory ids = new address[](listings.length);
    IEngine.BorrowUpdate[] memory borrowsUpdates = new IEngine.BorrowUpdate[](listings.length);
    IEngine.CollateralUpdate[] memory collateralsUpdates = new IEngine.CollateralUpdate[](
      listings.length
    );
    IEngine.PriceFeedUpdate[] memory priceFeedsUpdates = new IEngine.PriceFeedUpdate[](
      listings.length
    );

    IEngine.Basic[] memory basics = new IEngine.Basic[](listings.length);
    IV2RateStrategyFactory.RateStrategyParams[]
      memory rates = new IV2RateStrategyFactory.RateStrategyParams[](listings.length);

    for (uint256 i = 0; i < listings.length; i++) {
      require(listings[i].base.asset != address(0), 'INVALID_ASSET');
      ids[i] = listings[i].base.asset;
      basics[i] = IEngine.Basic({
        assetSymbol: listings[i].base.assetSymbol,
        assetName: listings[i].base.assetName,
        implementations: listings[i].implementations
      });
      priceFeedsUpdates[i] = IEngine.PriceFeedUpdate({
        asset: listings[i].base.asset,
        priceFeed: listings[i].base.priceFeed
      });
      borrowsUpdates[i] = IEngine.BorrowUpdate({
        asset: listings[i].base.asset,
        enabledToBorrow: listings[i].base.enabledToBorrow,
        stableRateModeEnabled: listings[i].base.stableRateModeEnabled,
        reserveFactor: listings[i].base.reserveFactor
      });
      collateralsUpdates[i] = IEngine.CollateralUpdate({
        asset: listings[i].base.asset,
        ltv: listings[i].base.ltv,
        liqThreshold: listings[i].base.liqThreshold,
        liqBonus: listings[i].base.liqBonus
      });
    }

    return
      IEngine.RepackedListings(
        ids,
        basics,
        borrowsUpdates,
        collateralsUpdates,
        priceFeedsUpdates,
        rates
      );
  }

  /// @dev mandatory configurations for any asset getting listed, including oracle config and basic init
  function _initAssets(
    IEngine.PoolContext calldata context,
    IPoolConfigurator poolConfigurator,
    IV2RateStrategyFactory rateStrategiesFactory,
    address collector,
    address rewardsController,
    address[] memory ids,
    IEngine.Basic[] memory basics,
    IV2RateStrategyFactory.RateStrategyParams[] memory rates
  ) internal {
    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](ids.length);
    address[] memory strategies = rateStrategiesFactory.createStrategies(rates);

    for (uint256 i = 0; i < ids.length; i++) {
      uint8 decimals = IERC20Metadata(ids[i]).decimals();
      require(decimals > 0, 'INVALID_ASSET_DECIMALS');

      initReserveInputs[i] = ConfiguratorInputTypes.InitReserveInput({
        aTokenImpl: basics[i].implementations.aToken,
        stableDebtTokenImpl: basics[i].implementations.sToken,
        variableDebtTokenImpl: basics[i].implementations.vToken,
        underlyingAssetDecimals: decimals,
        interestRateStrategyAddress: strategies[i],
        underlyingAsset: ids[i],
        treasury: collector,
        incentivesController: rewardsController,
        underlyingAssetName: basics[i].assetName,
        aTokenName: string.concat('Aave ', context.networkName, ' ', basics[i].assetSymbol),
        aTokenSymbol: string.concat('a', context.networkAbbreviation, basics[i].assetSymbol),
        variableDebtTokenName: string.concat(
          'Aave ',
          context.networkName,
          ' Variable Debt ',
          basics[i].assetSymbol
        ),
        variableDebtTokenSymbol: string.concat(
          'variableDebt',
          context.networkAbbreviation,
          basics[i].assetSymbol
        ),
        stableDebtTokenName: string.concat(
          'Aave ',
          context.networkName,
          ' Stable Debt ',
          basics[i].assetSymbol
        ),
        stableDebtTokenSymbol: string.concat(
          'stableDebt',
          context.networkAbbreviation,
          basics[i].assetSymbol
        ),
        params: bytes('')
      });
    }
    poolConfigurator.batchInitReserve(initReserveInputs);
  }
}
