//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {TokenPool, IERC20} from "@ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/libraries/Pool.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

/**
 * @title RebaseTokenPool
 * @author AlenIssacSam
 * @notice This is a TokenPool implementation for the RebaseToken
 */
contract RebaseTokenPool is TokenPool {

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        IERC20 _token,
        address[] memory _allowlist,
        address _rmnProxy,
        address _router
    ) TokenPool(_token, _allowlist, _rmnProxy, _router) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks or burns tokens from the sender and prepares data for cross-chain transfer
     * @param lockOrBurnIn The input data for the lock or burn operation
     * @return lockOrBurnOut The output data containing destination token address and pool data
     */
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);

        uint256 userInterestRate = IRebaseToken(address(i_token))
            .getUserInterestRate(lockOrBurnIn.originalSender);

        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: abi.encode(address(i_token)),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /**
     * @notice Releases or mints tokens to the receiver based on cross-chain transfer data
     * @param releaseOrMintIn The input data for the release or mint operation
     * @return releaseOrMintOut The output data containing the amount of tokens released or minted
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) external returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut) {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(
            releaseOrMintIn.sourcePoolData,
            (uint256)
        );
        IRebaseToken(address(i_token)).mint(
            releaseOrMintIn.receiver,
            releaseOrMintIn.amount,
            userInterestRate
        );

        releaseOrMintOut = Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }
}
