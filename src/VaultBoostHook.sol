// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IPrizeHooks } from "../lib/pt-v5-vault/src/interfaces/IPrizeHooks.sol";
import { PrizePool } from "../lib/pt-v5-prize-pool/src/PrizePool.sol";
import { NUMBER_OF_CANARY_TIERS } from "../lib/pt-v5-prize-pool/src/abstract/TieredLiquidityDistributor.sol";

/// @title PoolTogether V5 - Vault Boost Hook
/// @notice Uses both hook calls to redirect daily prizes won back to the prize pool and contribute them on
/// behalf of another vault.
/// @author G9 Software Inc.
contract VaultBoostHook is IPrizeHooks {
    /// @notice Thrown if the prize pool address is the zero address.
    error PrizePoolAddressZero();

    /// @notice Emitted when a daily prize is contributed to the prize pool on behalf of a vault beneficiary
    event BoostedPrizeVault(
        PrizePool indexed prizePool,
        address indexed vaultBeneficiary,
        address indexed booster,
        uint256 amount
    );

    /// @notice Emitted when a booster sets a new vault beneficiary
    event SetVaultBeneficiary(address indexed booster, address indexed vaultBeneficiary);

    /// @notice The prize pool to contribute prizes on behalf of. This can be set by each user of the hook.
    PrizePool public immutable PRIZE_POOL;

    /// @notice Mapping of boosters to vaults that the corresponding booster will contributed prizes on behalf of
    mapping(address booster => address beneficiary) public vaultBeneficiary;

    /// @notice Constructs a new Vault Boost Hook contract.
    /// @param prizePool_ The prize pool that the prizes originate from
    constructor(PrizePool prizePool_) {
        if (address(0) == address(prizePool_)) revert PrizePoolAddressZero();
        PRIZE_POOL = prizePool_;
    }

    /// @notice Sets a personal vault beneficiary address.
    /// @dev Set this to zero pause any boosting without having to remove the hook.
    /// @param vault The vault to contribute prizes on behalf of
    function setVaultBeneficiary(address vault) external {
        vaultBeneficiary[msg.sender] = vault;
        emit SetVaultBeneficiary(msg.sender, vault);
    }

    /// @inheritdoc IPrizeHooks
    /// @dev Returns the prize pool address as the prize recipient address if it's a daily prize.
    function beforeClaimPrize(
        address booster,
        uint8 tier,
        uint32,
        uint96,
        address
    ) external view returns (address prizeRecipient, bytes memory data) {
        // Only redirect for daily prizes and ensure that booster has a beneficiary set
        if (
            vaultBeneficiary[booster] != address(0) && tier >= PRIZE_POOL.numberOfTiers() - NUMBER_OF_CANARY_TIERS - 1
        ) {
            prizeRecipient = address(PRIZE_POOL);
        } else {
            prizeRecipient = booster;
        }
    }

    /// @inheritdoc IPrizeHooks
    /// @dev Contributes the prize amount back to the prize pool on behalf of the specified vault.
    function afterClaimPrize(
        address booster,
        uint8,
        uint32,
        uint256 prizeAmount,
        address prizeRecipient,
        bytes memory
    ) external {
        if (prizeRecipient == address(PRIZE_POOL) && prizeAmount > 0) {
            address beneficiary = vaultBeneficiary[booster];
            PRIZE_POOL.contributePrizeTokens(beneficiary, prizeAmount);
            emit BoostedPrizeVault(PRIZE_POOL, beneficiary, booster, prizeAmount);
        }
    }
}
