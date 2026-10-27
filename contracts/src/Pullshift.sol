// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Pullshift
/// @notice Two-side native BOT rounds with a capped rolling timer and pro-rata winner claims.
contract Pullshift {
    uint256 public constant MIN_PULL = 0.001 ether;
    uint64 public constant TIMER_EXTENSION = 4 hours;
    uint64 public constant MAX_ROUND_LENGTH = 48 hours;

    enum Side { Ember, Tide }
    enum Outcome { Pending, Ember, Tide, Draw }

    struct Round {
        uint64 startedAt;
        uint64 endsAt;
        uint64 maxEndsAt;
        uint64 settledAt;
        uint256 emberPot;
        uint256 tidePot;
        uint256 pullCount;
        Outcome outcome;
        bool settled;
    }

    struct Position {
        uint256 ember;
        uint256 tide;
        bool claimed;
    }

    mapping(uint256 => Round) private _rounds;
    mapping(uint256 => mapping(address => Position)) private _positions;
    uint256 public currentRound = 1;
    uint256 private _entered = 1;

    event Pulled(uint256 indexed roundId, address indexed player, Side indexed side, uint256 amount, uint64 endsAt);
    event RoundSettled(uint256 indexed roundId, Outcome outcome, uint256 emberPot, uint256 tidePot);
    event Claimed(uint256 indexed roundId, address indexed player, uint256 amount);
    event NextRoundOpened(uint256 indexed roundId);

    modifier nonReentrant() { require(_entered == 1, "reentrancy"); _entered = 2; _; _entered = 1; }

    receive() external payable { revert("use pull"); }

    function pull(Side side) external payable nonReentrant {
        require(msg.value >= MIN_PULL, "below minimum");
        Round storage game = _rounds[currentRound];
        require(!game.settled, "round settled");
        uint64 now64 = uint64(block.timestamp);

        if (game.startedAt == 0) {
            game.startedAt = now64;
            game.maxEndsAt = now64 + MAX_ROUND_LENGTH;
            game.endsAt = now64 + TIMER_EXTENSION;
        } else {
            require(block.timestamp < game.endsAt, "timer ended");
            uint64 extended = now64 + TIMER_EXTENSION;
            game.endsAt = extended < game.maxEndsAt ? extended : game.maxEndsAt;
        }

        Position storage user = _positions[currentRound][msg.sender];
        if (side == Side.Ember) { game.emberPot += msg.value; user.ember += msg.value; }
        else { game.tidePot += msg.value; user.tide += msg.value; }
        game.pullCount += 1;
        emit Pulled(currentRound, msg.sender, side, msg.value, game.endsAt);
    }

    function settle() external {
        Round storage game = _rounds[currentRound];
        require(game.startedAt != 0, "round not started");
        require(!game.settled, "already settled");
        require(block.timestamp >= game.endsAt, "timer active");
        game.settled = true;
        game.settledAt = uint64(block.timestamp);
        if (game.emberPot > game.tidePot) game.outcome = Outcome.Ember;
        else if (game.tidePot > game.emberPot) game.outcome = Outcome.Tide;
        else game.outcome = Outcome.Draw;
        emit RoundSettled(currentRound, game.outcome, game.emberPot, game.tidePot);
    }

    function claim(uint256 roundId) external nonReentrant returns (uint256 payout) {
        Round storage game = _rounds[roundId];
        require(game.settled, "not settled");
        Position storage user = _positions[roundId][msg.sender];
        require(!user.claimed, "already claimed");
        user.claimed = true;

        if (game.outcome == Outcome.Draw) payout = user.ember + user.tide;
        else if (game.outcome == Outcome.Ember && user.ember > 0) payout = (user.ember * (game.emberPot + game.tidePot)) / game.emberPot;
        else if (game.outcome == Outcome.Tide && user.tide > 0) payout = (user.tide * (game.emberPot + game.tidePot)) / game.tidePot;
        require(payout > 0, "nothing to claim");
        (bool ok, ) = payable(msg.sender).call{value: payout}("");
        require(ok, "payment failed");
        emit Claimed(roundId, msg.sender, payout);
    }

    function openNextRound() external {
        require(_rounds[currentRound].settled, "settle current round");
        currentRound += 1;
        emit NextRoundOpened(currentRound);
    }

    function round(uint256 roundId) external view returns (Round memory) { return _rounds[roundId]; }
    function position(uint256 roundId, address player) external view returns (Position memory) { return _positions[roundId][player]; }

    function previewClaim(uint256 roundId, address player) external view returns (uint256) {
        Round memory game = _rounds[roundId]; Position memory user = _positions[roundId][player];
        if (!game.settled || user.claimed) return 0;
        if (game.outcome == Outcome.Draw) return user.ember + user.tide;
        if (game.outcome == Outcome.Ember && user.ember > 0) return (user.ember * (game.emberPot + game.tidePot)) / game.emberPot;
        if (game.outcome == Outcome.Tide && user.tide > 0) return (user.tide * (game.emberPot + game.tidePot)) / game.tidePot;
        return 0;
    }
}