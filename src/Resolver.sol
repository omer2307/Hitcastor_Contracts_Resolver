// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IMarketFactory.sol";

contract Resolver is Ownable, Pausable, ReentrancyGuard {
    struct EvidenceSide {
        string csvUrl;
        bytes32 csvSha256;
        string jsonUrl;
        bytes32 jsonSha256;
        string ipfsCid;
    }

    struct Evidence {
        EvidenceSide t0;
        EvidenceSide t1;
    }

    struct CommitInfo {
        address committer;
        uint64 committedAt;
        bytes32 commitment;
        bool exists;
    }

    uint256 public disputeWindow;
    address public marketFactory;
    mapping(uint256 => CommitInfo) public commits;
    mapping(uint256 => bool) public resolved;

    event ResolveCommitted(
        uint256 indexed marketId,
        bytes32 commitment,
        Evidence evidence,
        address indexed committer,
        uint64 committedAt,
        uint256 disputeWindow
    );

    event Resolved(
        uint256 indexed marketId,
        uint8 outcome,
        uint16 t0Rank,
        uint16 t1Rank,
        Evidence evidence,
        address indexed finalizer
    );

    event DisputeWindowSet(uint256 oldWindow, uint256 newWindow);
    event MarketFactorySet(address indexed oldFactory, address indexed newFactory);

    error ErrNoCommit();
    error ErrTooEarly();
    error ErrCommitmentMismatch();
    error ErrAlreadyResolved();
    error ErrPaused();

    constructor(address _marketFactory, uint256 _disputeWindow) Ownable(msg.sender) {
        marketFactory = _marketFactory;
        disputeWindow = _disputeWindow;
    }

    function setDisputeWindow(uint256 newWindow) external onlyOwner {
        uint256 oldWindow = disputeWindow;
        disputeWindow = newWindow;
        emit DisputeWindowSet(oldWindow, newWindow);
    }

    function setMarketFactory(address mf) external onlyOwner {
        address oldFactory = marketFactory;
        marketFactory = mf;
        emit MarketFactorySet(oldFactory, mf);
    }

    function commitResolve(
        uint256 marketId,
        bytes32 commitment,
        Evidence calldata ev
    ) external whenNotPaused {
        if (resolved[marketId]) {
            revert ErrAlreadyResolved();
        }

        CommitInfo storage commitInfo = commits[marketId];
        if (commitInfo.exists && commitInfo.commitment != commitment) {
            revert ErrCommitmentMismatch();
        }

        commitInfo.committer = msg.sender;
        commitInfo.committedAt = uint64(block.timestamp);
        commitInfo.commitment = commitment;
        commitInfo.exists = true;

        emit ResolveCommitted(
            marketId,
            commitment,
            ev,
            msg.sender,
            uint64(block.timestamp),
            disputeWindow
        );
    }

    function finalizeResolve(
        uint256 marketId,
        uint8 outcome,
        uint16 t0Rank,
        uint16 t1Rank,
        Evidence calldata ev
    ) external whenNotPaused nonReentrant {
        if (resolved[marketId]) {
            revert ErrAlreadyResolved();
        }

        CommitInfo storage commitInfo = commits[marketId];
        if (!commitInfo.exists) {
            revert ErrNoCommit();
        }

        if (block.timestamp < commitInfo.committedAt + disputeWindow) {
            revert ErrTooEarly();
        }

        bytes32 recomputed = keccak256(
            abi.encode(
                marketId,
                t0Rank,
                t1Rank,
                outcome,
                ev.t0.csvUrl,
                ev.t0.csvSha256,
                ev.t0.jsonUrl,
                ev.t0.jsonSha256,
                ev.t0.ipfsCid,
                ev.t1.csvUrl,
                ev.t1.csvSha256,
                ev.t1.jsonUrl,
                ev.t1.jsonSha256,
                ev.t1.ipfsCid
            )
        );

        if (recomputed != commitInfo.commitment) {
            revert ErrCommitmentMismatch();
        }

        resolved[marketId] = true;

        IMarketFactory(marketFactory).applyOutcome(marketId, outcome, t0Rank, t1Rank);

        emit Resolved(marketId, outcome, t0Rank, t1Rank, ev, msg.sender);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
