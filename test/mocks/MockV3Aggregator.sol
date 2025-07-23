// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MockV3Aggregator
 * @notice A mock Chainlink AggregatorV3Interface contract for testing purposes.
 * @dev Allows setting arbitrary price answers and timestamps for simulating Chainlink feed behavior.
 */
contract MockV3Aggregator {
    uint256 public constant version = 0;

    uint8 public decimals;
    int256 public latestAnswer;
    uint256 public latestTimestamp;
    uint256 public latestRound;

    mapping(uint256 => int256) public getAnswer;
    mapping(uint256 => uint256) public getTimestamp;
    mapping(uint256 => uint256) private getStartedAt;

    /**
     * @notice Constructs a new MockV3Aggregator.
     * @param _decimals The number of decimal places for the price.
     * @param _initialAnswer The initial price answer to set.
     */
    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        updateAnswer(_initialAnswer);
    }

    /**
     * @notice Updates the latest price answer and increments the round.
     * @param _answer The new price answer.
     */
    function updateAnswer(int256 _answer) public {
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    /**
     * @notice Updates specific round data.
     * @param _roundId The round ID to update.
     * @param _answer The answer for the specified round.
     * @param _timestamp The timestamp for the specified round.
     * @param _startedAt The started-at timestamp for the specified round.
     */
    function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    /**
     * @notice Retrieves historical round data.
     * @param _roundId The ID of the round to query.
     * @return roundId The queried round ID.
     * @return answer The price answer for the queried round.
     * @return startedAt The timestamp when the round started.
     * @return updatedAt The timestamp when the answer was last updated.
     * @return answeredInRound The round ID in which the answer was finalized.
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    /**
     * @notice Retrieves the latest round data.
     * @return roundId The latest round ID.
     * @return answer The latest price answer.
     * @return startedAt The timestamp when the latest round started.
     * @return updatedAt The timestamp when the latest answer was updated.
     * @return answeredInRound The round ID in which the latest answer was finalized.
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    /**
     * @notice Returns a description of the mock aggregator.
     * @return A string describing the mock.
     */
    function description() external pure returns (string memory) {
        return "v0.6/tests/MockV3Aggregator.sol";
    }
}
