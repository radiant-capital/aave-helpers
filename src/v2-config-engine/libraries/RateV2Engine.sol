// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EngineFlags} from '../../v3-config-engine/EngineFlags.sol';
import {IAaveV2ConfigEngine as IEngine, ILendingPoolConfigurator as IPoolConfigurator, IV2RateStrategyFactory} from '../IAaveV2ConfigEngine.sol';

library RateV2Engine {
  function executeRateStrategiesUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.RateStrategyUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    (
      address[] memory ids,
      IV2RateStrategyFactory.RateStrategyParams[] memory rates
    ) = _repackRatesUpdate(updates);

    _configRateStrategies(
      engineConstants.poolConfigurator,
      engineConstants.ratesStrategyFactory,
      ids,
      rates
    );
  }

  function _configRateStrategies(
    IPoolConfigurator poolConfigurator,
    IV2RateStrategyFactory rateStrategiesFactory,
    address[] memory ids,
    IV2RateStrategyFactory.RateStrategyParams[] memory strategiesParams
  ) internal {
    for (uint256 i = 0; i < strategiesParams.length; i++) {
      if (
        strategiesParams[i].variableRateSlope1 == EngineFlags.KEEP_CURRENT ||
        strategiesParams[i].variableRateSlope2 == EngineFlags.KEEP_CURRENT ||
        strategiesParams[i].optimalUtilizationRate == EngineFlags.KEEP_CURRENT ||
        strategiesParams[i].baseVariableBorrowRate == EngineFlags.KEEP_CURRENT ||
        strategiesParams[i].stableRateSlope1 == EngineFlags.KEEP_CURRENT ||
        strategiesParams[i].stableRateSlope2 == EngineFlags.KEEP_CURRENT
      ) {
        IV2RateStrategyFactory.RateStrategyParams memory currentStrategyData = rateStrategiesFactory
          .getStrategyDataOfAsset(ids[i]);

        if (strategiesParams[i].variableRateSlope1 == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].variableRateSlope1 = currentStrategyData.variableRateSlope1;
        }

        if (strategiesParams[i].variableRateSlope2 == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].variableRateSlope2 = currentStrategyData.variableRateSlope2;
        }

        if (strategiesParams[i].optimalUtilizationRate == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].optimalUtilizationRate = currentStrategyData.optimalUtilizationRate;
        }

        if (strategiesParams[i].baseVariableBorrowRate == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].baseVariableBorrowRate = currentStrategyData.baseVariableBorrowRate;
        }

        if (strategiesParams[i].stableRateSlope1 == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].stableRateSlope1 = currentStrategyData.stableRateSlope1;
        }

        if (strategiesParams[i].stableRateSlope2 == EngineFlags.KEEP_CURRENT) {
          strategiesParams[i].stableRateSlope2 = currentStrategyData.stableRateSlope2;
        }
      }
    }

    address[] memory strategies = rateStrategiesFactory.createStrategies(strategiesParams);

    for (uint256 i = 0; i < strategies.length; i++) {
      poolConfigurator.setReserveInterestRateStrategyAddress(ids[i], strategies[i]);
    }
  }

  function _repackRatesUpdate(
    IEngine.RateStrategyUpdate[] memory updates
  ) internal pure returns (address[] memory, IV2RateStrategyFactory.RateStrategyParams[] memory) {
    address[] memory ids = new address[](updates.length);
    IV2RateStrategyFactory.RateStrategyParams[]
      memory rates = new IV2RateStrategyFactory.RateStrategyParams[](updates.length);

    for (uint256 i = 0; i < updates.length; i++) {
      ids[i] = updates[i].asset;
      rates[i] = updates[i].params;
    }
    return (ids, rates);
  }
}
