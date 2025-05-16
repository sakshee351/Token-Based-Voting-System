// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Project
 * @dev Token-Based Voting System with core governance functionalities
 */
contract Project is ERC20, Ownable {
    // Proposal struct to store proposal details
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    // Proposal counter
    uint256 public proposalCount;
    
    // Minimum token balance required to create a proposal (e.g., 100 tokens)
    uint256 public proposalThreshold = 100 * 10**18;
    
    // Standard voting period in seconds (3 days)
    uint256 public votingPeriod = 3 days;
    
    // Mapping from proposal id to proposal
    mapping(uint256 => Proposal) public proposals;
    
    // Delegation system
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedPower;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title, uint256 startTime, uint256 endTime);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    constructor(string memory name, string memory symbol, uint256 initialSupply) 
        ERC20(name, symbol) 
        Ownable(msg.sender) 
    {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Create a new proposal
     * @param title Title of the proposal
     * @param description Description of the proposal
     * @return The ID of the newly created proposal
     */
    function createProposal(string memory title, string memory description) external returns (uint256) {
        // Check if sender has enough tokens to create proposal
        require(
            getVotingPower(msg.sender) >= proposalThreshold,
            "Project: proposer votes below threshold"
        );

        uint256 proposalId = proposalCount++;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalId, msg.sender, title, proposal.startTime, proposal.endTime);

        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support True for 'For', False for 'Against'
     */
    function castVote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.startTime, "Project: voting hasn't started");
        require(block.timestamp <= proposal.endTime, "Project: voting is closed");
        require(!proposal.hasVoted[msg.sender], "Project: already voted");
        
        uint256 votingPower = getVotingPower(msg.sender);
        require(votingPower > 0, "Project: caller has no voting power");
        
        // Mark as voted
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @dev Delegate votes from sender to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external {
        address delegator = msg.sender;
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);

        if (currentDelegate != address(0)) {
            delegatedPower[currentDelegate] -= delegatorBalance;
        }

        if (delegatee != address(0)) {
            delegatedPower[delegatee] += delegatorBalance;
        }

        delegates[delegator] = delegatee;
        
        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }

    /**
     * @dev Get total voting power for an address (own balance + delegated)
     * @param account The address to get voting power for
     * @return The total voting power
     */
    function getVotingPower(address account) public view returns (uint256) {
        return balanceOf(account) + delegatedPower[account];
    }

    /**
     * @dev Override transfer function to update delegations
     */
    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);

        // Update delegation if the sender has delegated
        address fromDelegate = delegates[from];
        if (fromDelegate != address(0)) {
            delegatedPower[fromDelegate] -= amount;
        }

        // Update delegation if the recipient has delegated
        address toDelegate = delegates[to];
        if (toDelegate != address(0)) {
            delegatedPower[toDelegate] += amount;
        }
    }
}
