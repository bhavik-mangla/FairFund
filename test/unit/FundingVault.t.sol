// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {FundingVault} from "../../src/FundingVault.sol";
import {VotingPowerToken} from "../../src/VotingPowerToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FundingVaultTest is Test {
    FundingVault fundingVault;
    MockERC20 fundingToken;
    MockERC20 votingToken;
    VotingPowerToken votingPowerToken;
    address owner = makeAddr("owner");
    address randomUser = makeAddr("randomUser");
    address randomUser1 = makeAddr("randomUser1");

    function setUp() external {
        fundingToken = new MockERC20("FundingToken", "FTK");
        votingToken = new MockERC20("VotingToken", "VTK");
        votingPowerToken = new VotingPowerToken("VotingPowerToken", "VOTE");
        fundingVault = new FundingVault(
            address(fundingToken),
            address(votingToken),
            address(votingPowerToken),
            0,
            10 ether,
            block.timestamp + 1 days,
            owner
        );
        votingPowerToken.transferOwnership(address(fundingVault));
    }

    function testSetMinRequestableAmount() public {
        vm.prank(owner);
        fundingVault.setMinRequestableAmount(2 ether);
        assertEq(fundingVault.getMinRequestableAmount(), 2 ether);
    }

    function testSetMaxRequestableAmount() public {
        vm.prank(owner);
        fundingVault.setMaxRequestableAmount(20 ether);
        assertEq(fundingVault.getMaxRequestableAmount(), 20 ether);
    }

    function testDeposit() public {
        vm.startPrank(randomUser);
        fundingToken.mint(randomUser, 10 ether);
        fundingToken.approve(address(fundingVault), 10 ether);
        fundingVault.deposit(10 ether);
        assertEq(fundingToken.balanceOf(address(fundingVault)), 10 ether);
        vm.stopPrank();
    }

    function testRegister() public {
        vm.startPrank(randomUser);
        votingToken.mint(randomUser, 10 ether);
        votingToken.approve(address(fundingVault), 10 ether);
        fundingVault.register(10 ether);
        assertEq(votingToken.balanceOf(address(fundingVault)), 10 ether);
        assertEq(votingPowerToken.balanceOf(randomUser), 10 ether);
        vm.stopPrank();
    }

    function testSubmitProposal() public {
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 5 ether, address(randomUser));
        (string memory metadata, uint256 minAmount, uint256 maxAmount, address recipient) = fundingVault.getProposal(1);
        assertEq(metadata, "<Proposal Link>");
        assertEq(minAmount, 1 ether);
        assertEq(maxAmount, 5 ether);
        assertEq(recipient, address(randomUser));
    }

    function testVoteOnProposal() public {
        // Setup
        vm.startPrank(randomUser);
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 5 ether, address(randomUser));
        vm.stopPrank();

        // Vote on the proposal
        vm.startPrank(randomUser1);
        votingToken.mint(randomUser1, 10 ether);
        votingToken.approve(address(fundingVault), 10 ether);
        fundingVault.register(10 ether);
        votingPowerToken.approve(address(fundingVault), 5 ether);
        fundingVault.voteOnProposal(1, 5 ether);
        assertEq(votingPowerToken.balanceOf(address(fundingVault)), 5 ether);
        vm.stopPrank();
    }

    function testDistributeFunds() public {
        // Setup
        vm.startPrank(randomUser);
        fundingToken.mint(randomUser, 10 ether);
        fundingToken.approve(address(fundingVault), 10 ether);
        fundingVault.deposit(10 ether);
        votingToken.mint(randomUser, 10 ether);
        votingToken.approve(address(fundingVault), 10 ether);
        fundingVault.register(10 ether);
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 8 ether, address(randomUser));
        votingPowerToken.approve(address(fundingVault), 8 ether);
        fundingVault.voteOnProposal(1, 8 ether);
        vm.stopPrank();

        // Fast forward time to pass the tally date
        vm.warp(block.timestamp + 2 days);

        // Distribute funds
        vm.prank(randomUser);
        fundingVault.distributeFunds();
        assertEq(fundingToken.balanceOf(randomUser), 8 ether); // Proposal should receive 5 ether
    }

    function testReleaseVotingTokens() public {
        // Setup
        vm.startPrank(randomUser);
        votingToken.mint(randomUser, 10 ether);
        votingToken.approve(address(fundingVault), 10 ether);
        fundingVault.register(10 ether);
        vm.stopPrank();

        // Fast forward time to pass the tally date
        vm.warp(block.timestamp + 2 days);

        // Release voting tokens
        vm.prank(randomUser);
        fundingVault.releaseVotingTokens();
        assertEq(votingToken.balanceOf(randomUser), 10 ether);
        assertEq(fundingVault.getVotingPowerOf(msg.sender), 0);
    }

    function testSubmitProposalWithZeroMetadata() public {
        vm.expectRevert(FundingVault.FundingVault__MetadataCannotBeEmpty.selector);
        fundingVault.submitProposal("", 1 ether, 5 ether, address(randomUser));
    }

    function testSubmitProposalWithInvalidAmounts() public {
        vm.expectRevert(FundingVault.FundingVault__AmountExceededsLimit.selector);
        fundingVault.submitProposal("<Proposal Link>", 0, 5 ether, address(randomUser));

        vm.expectRevert(FundingVault.FundingVault__AmountExceededsLimit.selector);
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 11 ether, address(randomUser));
    }

    function testSubmitProposalWithZeroAddress() public {
        vm.expectRevert(FundingVault.FundingVault__CannotBeAZeroAddress.selector);
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 5 ether, address(0));
    }

    function testVoteOnNonExistentProposal() public {
        vm.expectRevert(FundingVault.FundingVault__ProposalDoesNotExist.selector);
        fundingVault.voteOnProposal(999, 1 ether);
    }

    function testVoteWithExcessiveAmount() public {
        // Setup
        vm.startPrank(randomUser);
        votingToken.mint(randomUser, 10 ether);
        votingToken.approve(address(fundingVault), 10 ether);
        fundingVault.register(10 ether);
        fundingVault.submitProposal("<Proposal Link>", 1 ether, 5 ether, address(randomUser));
        vm.stopPrank();

        // Attempt to vote with more tokens than owned
        vm.startPrank(randomUser);
        votingPowerToken.approve(address(fundingVault), 20 ether);
        vm.expectRevert(FundingVault.FundingVault__AmountExceededsLimit.selector);
        fundingVault.voteOnProposal(1, 20 ether);
        vm.stopPrank();
    }
}