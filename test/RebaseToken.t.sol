//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address private owner = makeAddr("owner");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        payable(address(vault)).call{value: 100 ether}("");

        vm.stopPrank();
    }

    function addRewardToVault(uint256 amount) public {
        payable(address(vault)).call{value: amount}("");
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1 ether, type(uint128).max);

        vm.startPrank(user1);
        vm.deal(user1, amount);

        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("Start balance:", startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfter1Hour = rebaseToken.balanceOf(user1);
        console.log("Balance after 1 hour:", balanceAfter1Hour);

        assertGt(balanceAfter1Hour, startBalance);

        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfter2Hours = rebaseToken.balanceOf(user1);
        console.log("Balance after 2 hours:", balanceAfter2Hours);

        assertGt(balanceAfter2Hours, balanceAfter1Hour);

        assertApproxEqAbs(
            balanceAfter2Hours - balanceAfter1Hour,
            balanceAfter1Hour - startBalance,
            1
        );

        vm.stopPrank();
    }

    function testRedeemStraightforward(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint128).max);

        vm.startPrank(user1);
        vm.deal(user1, amount);

        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("Start balance:", startBalance);
        assertEq(startBalance, amount);

        vault.redeem(type(uint256).max);

        uint256 finalEthBalance = user1.balance;
        console.log("Final ETH balance:", finalEthBalance);

        assertEq(finalEthBalance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterTime(uint256 amount, uint256 time) public {
        time = bound(time, 1000, type(uint72).max);
        amount = bound(amount, 1e5, type(uint128).max);

        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();

        uint256 startBalance = rebaseToken.balanceOf(user1);
        console.log("Start balance:", startBalance);

        vm.warp(block.timestamp + time);
        uint256 balanceAfterTime = rebaseToken.balanceOf(user1);
        console.log("Balance after time:", balanceAfterTime);

        vm.stopPrank();

        vm.prank(owner);
        vm.deal(owner, balanceAfterTime - startBalance);
        addRewardToVault(balanceAfterTime - startBalance); // Adding extra 1 ether to ensure vault has enough balance

        vm.startPrank(user1);
        vault.redeem(type(uint256).max);

        uint256 finalEthBalance = address(user1).balance;
        console.log("Final ETH balance:", finalEthBalance);

        assertEq(finalEthBalance, balanceAfterTime);
        assertGt(finalEthBalance, amount);

        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint128).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        // Ensure amount is large enough to prevent reverts in amountToSend bounding
        amount = bound(amount, 2e5, type(uint128).max);
        // Ensure amountToSend is always less than amount
        amountToSend = bound(amountToSend, 1e5, amount - 1);

        vm.deal(user1, amount);
        vm.prank(user1);
        vault.deposit{value: amount}();

        uint256 user1StartBalance = rebaseToken.balanceOf(user1);
        console.log("User1 Start balance:", user1StartBalance);
        assertEq(user1StartBalance, amount);

        uint256 user2StartBalance = rebaseToken.balanceOf(user2);
        console.log("User2 Start balance:", user2StartBalance);
        assertEq(user2StartBalance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user1);
        rebaseToken.transfer(user2, amountToSend);
        uint256 user1EndBalance = rebaseToken.balanceOf(user1);
        console.log("User1 End balance:", user1EndBalance);

        assertEq(user1EndBalance, amount - amountToSend);
        assertEq(rebaseToken.balanceOf(user2), amountToSend);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user1), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user1);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint128).max);

        vm.prank(user1);
        vm.expectPartialRevert(
            IAccessControl.AccessControlUnauthorizedAccount.selector
        );
        rebaseToken.mint(user1, amount, rebaseToken.getInterestRate());

        vm.prank(user1);
        vm.expectPartialRevert(
            IAccessControl.AccessControlUnauthorizedAccount.selector
        );
        rebaseToken.burn(user1, amount);
    }

    function testGetPrincipalBalance(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(user1, amount);
        vm.prank(user1);
        vault.deposit{value: amount}();

        uint256 principalBalance = rebaseToken.principalBalanceOf(user1);
        console.log("Principal balance:", principalBalance);

        assertEq(principalBalance, amount);

        vm.warp(block.timestamp + 1 days);
        principalBalance = rebaseToken.principalBalanceOf(user1);
        console.log("Principal balance after 1 day:", principalBalance);

        assertEq(principalBalance, amount);
    }

    function testGetRebaseTokenAddress() public {
        address rebaseTokenAddress = vault.getRebaseTokenAddress();
        console.log("RebaseToken address from Vault:", rebaseTokenAddress);
        assertEq(rebaseTokenAddress, address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 currentInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(
            newInterestRate,
            currentInterestRate,
            type(uint72).max
        );
        vm.prank(owner);
        vm.expectPartialRevert(
            RebaseToken.RebaseToken__InterestRateCannotIncrease.selector
        );
        rebaseToken.setInterestRate(newInterestRate);

        assertEq(rebaseToken.getInterestRate(), currentInterestRate);
    }
}
