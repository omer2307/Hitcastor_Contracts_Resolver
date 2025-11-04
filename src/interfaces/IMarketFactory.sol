// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMarketFactory {
    function applyOutcome(uint256 marketId, uint8 outcome, uint16 t0Rank, uint16 t1Rank) external;
}