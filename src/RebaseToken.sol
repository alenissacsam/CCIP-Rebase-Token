//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author AlenIssacSam
 * @notice This is a cross chain rebase token which incetivices users to deposit into a vault and gain interest
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate based on when they deposited into the vault
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestRateCannotIncrease(uint256 oldInterestRate, uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event InterestRateUpdated(uint256 indexed oldInterestRate, uint256 indexed newInterestRate);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets a new interest rate for the vault
     * @param _newInterestRate The new interest rate to be set
     * @dev The new interest rate cannot be greater than the current interest rate
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCannotIncrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(s_interestRate, _newInterestRate);
    }

    /**
     * @notice Mints new tokens to a user
     * @param _to The address of the user to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints the accrued interest for a user
     * @param _user The address of the user
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 interestToMint = balanceOf(_user) - super.balanceOf(_user);
        uint256 currentBalanceWithInterest = balanceOf(_user);
        uint256 principalBalance = super.balanceOf(_user);
        if (currentBalanceWithInterest > principalBalance) {
            uint256 interestToMint = currentBalanceWithInterest - principalBalance;
            _mint(_user, interestToMint);
        }
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, interestToMint);
    }

    /**
     * @notice Transfers tokens from one user to another
     * @param _to The address of the user to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return success A boolean indicating whether the transfer was successful
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (super.balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    /**
     * @notice Transfers tokens from one user to another on behalf of a third user
     * @param _from The address of the user to transfer tokens from
     * @param _to The address of the user to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return success A boolean indicating whether the transfer was successful
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if (super.balanceOf(_from) == 0) {
            s_userInterestRate[_to] - s_userInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice Calculates the accrued interest for a user
     * @param _user The address of the user
     * @return linearInterest The accrued interest for the user
     */
    function _calculateAccruedInterest(address _user) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the current interest rate of the vault
     * @return The current interest rate of the vault
     */
    function getInterestRate() public view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Gets the interest rate of a specific user
     * @param _user The address of the user
     * @return The interest rate of the user
     */
    function getUserInterestRate(address _user) public view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Calculates the accrued interest + Principal Amount for a user
     * @param _user The address of the user
     * @return Interest + Principal Amount for the user
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return (super.balanceOf(_user) * _calculateAccruedInterest(_user)) / PRECISION_FACTOR;
    }

    /**
     * @notice Gets the principal balance of a user
     * @param _user The address of the user
     * @return The principal balance of the user
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
