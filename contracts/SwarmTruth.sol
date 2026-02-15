// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@ora-io/contracts/interfaces/IAIOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SwarmTruth
 * @dev A decentralized multi-agent swarm for on-chain fact verification using ORA AI Oracle.
 * This contract allows users to post research bounties that are verified by an AI Oracle
 * before funds are released to the agent.
 */
contract SwarmTruth is Ownable {
    IAIOracle public aiOracle;
    
    // ORA Model ID (e.g., Llama 3)
    uint256 public constant MODEL_ID = 11; 

    struct Bounty {
        string question;
        uint256 reward;
        bool completed;
        address solver;
        string resultData;
    }

    mapping(uint256 => uint256) public requestIdToBountyId;
    Bounty[] public bounties;

    event BountyPosted(uint256 indexed bountyId, string question, uint256 reward);
    event ResponseSubmitted(uint256 indexed bountyId, uint256 requestId, address solver);
    event BountyCompleted(uint256 indexed bountyId, address solver, uint256 reward);
    event VerificationFailed(uint256 indexed bountyId, string reason);

    constructor(address _aiOracle) Ownable(msg.sender) {
        aiOracle = IAIOracle(_aiOracle);
    }

    /**
     * @notice Post a new research bounty.
     * @param _question The research question to be answered.
     */
    function postBounty(string memory _question) external payable {
        require(msg.value > 0, "Reward must be greater than zero");
        bounties.push(Bounty(_question, msg.value, false, address(0), ""));
        emit BountyPosted(bounties.length - 1, _question, msg.value);
    }

    /**
     * @notice Submit research data for a bounty. Triggers ORA AI Oracle verification.
     * @param _bountyId The ID of the bounty being solved.
     * @param _data The research data/answer to verify.
     */
    function submitResponse(uint256 _bountyId, string memory _data) external payable {
        Bounty storage b = bounties[_bountyId];
        require(!b.completed, "Bounty already completed");
        require(b.solver == address(0), "Bounty currently under verification");

        // Calculate ORA Fee
        uint256 fee = aiOracle.estimateFee(MODEL_ID);
        require(msg.value >= fee, "Insufficient fee for AI Oracle");

        // Construct verification prompt
        string memory prompt = string.concat(
            "Question: ", b.question, 
            " | Answer: ", _data, 
            " | Task: Reply with exactly 'YES' if the answer is accurate and complete, otherwise reply 'NO'."
        );

        uint256 requestId = aiOracle.calculateAIResult{value: fee}(MODEL_ID, prompt);
        requestIdToBountyId[requestId] = _bountyId;
        b.solver = msg.sender;
        b.resultData = _data;

        emit ResponseSubmitted(_bountyId, requestId, msg.sender);
    }

    /**
     * @notice Callback from ORA AI Oracle with the verification result.
     */
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata) external {
        require(msg.sender == address(aiOracle), "Only AI Oracle can callback");
        
        uint256 bountyId = requestIdToBountyId[requestId];
        Bounty storage b = bounties[bountyId];
        
        if (keccak256(output) == keccak256(bytes("YES"))) {
            b.completed = true;
            uint256 reward = b.reward;
            b.reward = 0;
            payable(b.solver).transfer(reward);
            emit BountyCompleted(bountyId, b.solver, reward);
        } else {
            // Reset solver so others can try if verification failed
            address failedSolver = b.solver;
            b.solver = address(0);
            emit VerificationFailed(bountyId, "AI Oracle rejected the accuracy of the submission");
        }
    }

    function getBountiesCount() external view returns (uint256) {
        return bounties.length;
    }

    // Allow owner to update oracle address if necessary
    function setAIOracle(address _aiOracle) external onlyOwner {
        aiOracle = IAIOracle(_aiOracle);
    }
}
