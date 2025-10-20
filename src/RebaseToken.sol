//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author AlenIssacSam
 * @notice This is a cross chain rebase token which incetivices users to deposit into a vault and gain interest
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate based on when they deposited into the vault
 */
contract RebaseToken is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error RebaseToken__InterestRateCannotIncrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    uint256 private constant PRECISON_FACTOR = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event InterestRateUpdated(
        uint256 indexed oldInterestRate,
        uint256 indexed newInterestRate
    );

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    constructor() ERC20("RebaseToken", "RBT") {}

    /**
     * @notice Sets a new interest rate for the vault
     * @param _newInterestRate The new interest rate to be set
     * @dev The new interest rate cannot be greater than the current interest rate
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCannotIncrease(
                s_interestRate,
                _newInterestRate
            );
        }

        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(s_interestRate, _newInterestRate);
    }

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;

        _mint(_to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintAccruedInterest(address _user) internal {
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
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
        return
            (super.balanceOf(_user) * _calculateAccruedInterest(_user)) /
            PRECISON_FACTOR;
    }

    /**
     * @notice Calculates the accrued interest for a user
     * @param _user The address of the user
     * @return linearInterest The accrued interest for the user
     */
    function _calculateAccruedInterest(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest =
            PRECISON_FACTOR +
            (s_userInterestRate[_user] * timeElapsed);
    }
}
