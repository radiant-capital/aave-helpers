// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EngineFlags} from '../../v3-config-engine/EngineFlags.sol';
import {ReserveConfiguration, DataTypes} from '../protocol-v2/ReserveConfiguration.sol';
import {IAaveV2ConfigEngine as IEngine, ILendingPoolConfigurator as IPoolConfigurator, ILendingPool as IPool} from '../IAaveV2ConfigEngine.sol';

library BorrowV2Engine {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function executeBorrowSide(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.BorrowUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configBorrowSide(engineConstants.poolConfigurator, engineConstants.pool, updates);
  }

  function _configBorrowSide(
    IPoolConfigurator poolConfigurator,
    IPool pool,
    IEngine.BorrowUpdate[] memory updates
  ) internal {
    for (uint256 i = 0; i < updates.length; i++) {
      if (updates[i].enabledToBorrow != EngineFlags.KEEP_CURRENT) {
        if (EngineFlags.toBool(updates[i].enabledToBorrow)) {
          poolConfigurator.enableBorrowingOnReserve(
            updates[i].asset,
            // We disable it here to avoid default activating stable rate borrowing
            false
          );
        } else {
          poolConfigurator.disableBorrowingOnReserve(updates[i].asset);
        }
      } else {
        DataTypes.ReserveConfigurationMap memory reserveConfig = pool.getConfiguration(
          updates[i].asset
        );
        (, , bool borrowingEnabled, ) = reserveConfig.getFlags();
        updates[i].enabledToBorrow = EngineFlags.fromBool(borrowingEnabled);
      }

      if (updates[i].enabledToBorrow == EngineFlags.ENABLED) {
        if (
          updates[i].stableRateModeEnabled != EngineFlags.KEEP_CURRENT &&
          EngineFlags.toBool(updates[i].stableRateModeEnabled)
        ) {
          poolConfigurator.enableReserveStableRate(updates[i].asset);
        } else {
          poolConfigurator.disableReserveStableRate(updates[i].asset);
        }
      }

      // The reserve factor should always be > 0
      require(
        (updates[i].reserveFactor > 0 && updates[i].reserveFactor <= 100_00) ||
          updates[i].reserveFactor == EngineFlags.KEEP_CURRENT,
        'INVALID_RESERVE_FACTOR'
      );

      if (updates[i].reserveFactor != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setReserveFactor(updates[i].asset, updates[i].reserveFactor);
      }
    }
  }
}
