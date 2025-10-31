//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {TokenPool,IERC20} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@chainlink/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        address[] memory _allowlist,
        address _rmnProxy,
        address _router
    ) TokenPool(_token, _allowlist, _rmnProxy, _router) {}

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);

        address receiver = abi.decode(lockOrBurnIn.receiver, (address));    
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(
            receiver
        );

        IRebaseToken(address(i_token)).burn(
            address(this),
            lockOrBurnIn.amount
        );

        lockOrBurnOut.destTokenAddress = abi.encode(address(i_token));
        lockOrBurnOut.destPoolData = abi.encode(userInterestRate);
    }

    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) external returns (Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMint(releaseOrMintIn);
    }

}
