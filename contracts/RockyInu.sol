// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./Context.sol";
import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./IUniswap.sol";

contract RockyInu is Context, IERC20, Ownable {
	using SafeMath for uint256;
	using Address for address;

	address payable public marketingAddress =
			payable(0x7b1245114698D1a661936C6846114bf84FdF3960); // Marketing Address
			
	address payable public liquidityAddress =
			payable(0x000000000000000000000000000000000000dEaD); // Liquidity Address
			
	address public immutable deadAddress =
			0x000000000000000000000000000000000000dEaD; // dead address
			
	mapping(address => uint256) private _rOwned;
	mapping(address => uint256) private _tOwned;
	mapping(address => mapping(address => uint256)) private _allowances;

	mapping(address => bool) private _isExcludedFromFee;

	mapping(address => bool) private _isExcluded;
	address[] private _excluded;
	
	uint256 private constant MAX = ~uint256(0);
	uint256 private constant _tTotal = 1 * 1e15 * 1e9;
	uint256 private _rTotal = (MAX - (MAX % _tTotal));
	uint256 private _tFeeTotal;

	string private constant _name = "Rocky Inu";
	string private constant _symbol = "ROCKY";
	uint8 private constant _decimals = 9;
	
	// Anti-bot and anti-whale mappings and variables
	mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
	bool public transferDelayEnabled = true;
	bool public limitsInEffect = true;
	
	uint256 private constant BUY = 1;
	uint256 private constant SELL = 2;
	uint256 private constant TRANSFER = 3;
	uint256 private buyOrSellSwitch;

	uint256 private _taxFee;
	uint256 private _previousTaxFee = _taxFee;

	uint256 private _liquidityFee;
	uint256 private _previousLiquidityFee = _liquidityFee;
	
	uint256 private _burnFee;
	uint256 private _previousBurnFee = _burnFee;

	uint256 public _buyTaxFee = 3;
	uint256 public _buyLiquidityFee = 3;
	uint256 public _buyMarketingFee = 6;
	uint256 public _buyBurnFee = 3;

	uint256 public _sellTaxFee = 3;
	uint256 public _sellLiquidityFee = 3;
	uint256 public _sellMarketingFee = 6;
	uint256 public _sellBurnFee = 3;
	
	uint256 public tradingActiveBlock = 0; // 0 means trading is not active
	mapping(address => bool) public boughtEarly;
	uint256 public earlyBuyPenaltyEnd;
	
	uint256 private _liquidityTokensToSwap;
	uint256 private _marketingTokensToSwap;
	
	uint256 public maxTransactionAmount;
	uint256 public maxWallet;
	mapping (address => bool) public _isExcludedMaxTransactionAmount;
	
	bool private gasLimitActive = true;
	uint256 private gasPriceLimit = 500 * 1 gwei; 
	uint256 private gasMaxLimit =  1000000 * 1 gwei; // gasLeft limit
	
	mapping (address => bool) public automatedMarketMakerPairs;

	uint256 private minimumTokensBeforeSwap = _tTotal * 5 / 10000; // 0.05%

	IUniswapV2Router02 public uniswapV2Router;
	address public uniswapV2Pair;

	bool inSwapAndLiquify;
	bool public swapAndLiquifyEnabled = false;
	bool public tradingActive = false;

	event SwapAndLiquifyEnabledUpdated(bool enabled);
	event SwapAndLiquify(
		uint256 tokensSwapped,
		uint256 ethReceived,
		uint256 tokensIntoLiquidity
	);

	event SwapETHForTokens(uint256 amountIn, address[] path);

	event SwapTokensForETH(uint256 amountIn, address[] path);
	
	event SetAutomatedMarketMakerPair(address pair, bool value);
	
	event ExcludeFromReward(address excludedAddress);
	
	event IncludeInReward(address includedAddress);
	
	event ExcludeFromFee(address excludedAddress);
	
	event IncludeInFee(address includedAddress);
	
	event SetBuyFee(uint256 marketingFee, uint256 liquidityFee, uint256 reflectFee, uint256 burnFee);
	
	event SetSellFee(uint256 marketingFee, uint256 liquidityFee, uint256 reflectFee, uint256 burnFee);
	
	event TransferForeignToken(address token, uint256 amount);
	
	event UpdatedMarketingAddress(address marketing);
	
	event UpdatedLiquidityAddress(address liquidity);
	
	event UpdatedBuyBackAddress(address buyback);
	
	event OwnerForcedSwapBack(uint256 timestamp);
	
	event BoughtEarly(address indexed sniper);
	
	event RemovedSniper(address indexed notsnipersupposedly);

	event UpdatedRouter(address indexed newrouter);
	
	modifier lockTheSwap() {
		inSwapAndLiquify = true;
		_;
		inSwapAndLiquify = false;
	}

	constructor() {
		address newOwner = address(0xD921ed7aEcC68353831f943893BaCe3380FeDF34);
		_rOwned[newOwner] = _rTotal;
		
		address _routerAddress = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_routerAddress);
		
		maxTransactionAmount = _tTotal * 1 / 100; // 1% maxTransactionAmountTxn
		minimumTokensBeforeSwap = _tTotal * 5 / 10000; // 0.05% swap tokens amount
		maxWallet = _tTotal * 3 / 100; // 3% max wallet

		IUniswapV2Factory _uniswapFactory = IUniswapV2Factory(_uniswapV2Router.factory());
		// address _weth = _uniswapV2Router.WETH();
		// address _uniswapV2Pair = _uniswapFactory.createPair(address(this), _weth);

		// uniswapV2Router = _uniswapV2Router;
		// uniswapV2Pair = _uniswapV2Pair;
		
		// _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
		
		// _isExcludedFromFee[newOwner] = true;
		// _isExcludedFromFee[address(this)] = true;
		// _isExcludedFromFee[marketingAddress] = true;
		// _isExcludedFromFee[liquidityAddress] = true;
		
		// emit Transfer(address(0), newOwner, _tTotal);
		
		// transferOwnership(newOwner);
	}

	function name() external pure returns (string memory) {
		return _name;
	}

	function symbol() external pure returns (string memory) {
		return _symbol;
	}

	function decimals() external pure returns (uint8) {
		return _decimals;
	}

	function totalSupply() external pure override returns (uint256) {
		return _tTotal;
	}

	function balanceOf(address account) public view override returns (uint256) {
		if (_isExcluded[account]) return _tOwned[account];
		return tokenFromReflection(_rOwned[account]);
	}

	function transfer(address recipient, uint256 amount)
		external
		override
		returns (bool)
	{
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function allowance(address owner, address spender)
		external
		view
		override
		returns (uint256)
	{
		return _allowances[owner][spender];
	}

	function approve(address spender, uint256 amount)
			external
			override
			returns (bool)
	{
			_approve(_msgSender(), spender, amount);
			return true;
	}

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) external override returns (bool) {
		_transfer(sender, recipient, amount);
		_approve(
			sender,
			_msgSender(),
			_allowances[sender][_msgSender()].sub(
				amount,
				"ERC20: transfer amount exceeds allowance"
			)
		);
		return true;
	}

	function increaseAllowance(address spender, uint256 addedValue)
			external
			virtual
			returns (bool)
	{
		_approve(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].add(addedValue)
		);
		return true;
	}

	function decreaseAllowance(address spender, uint256 subtractedValue)
			external
			virtual
			returns (bool)
	{
		_approve(
			_msgSender(),
			spender,
			_allowances[_msgSender()][spender].sub(
				subtractedValue,
				"ERC20: decreased allowance below zero"
			)
		);
		return true;
	}

	function isExcludedFromReward(address account)
		external
		view
		returns (bool)
	{
		return _isExcluded[account];
	}

	function totalFees() external view returns (uint256) {
		return _tFeeTotal;
	}
	
	function enableTrading() external onlyOwner {
		tradingActive = true;
		swapAndLiquifyEnabled = true;
		tradingActiveBlock = block.number;
		earlyBuyPenaltyEnd = block.timestamp + 72 hours;
	}
	
	function disableTransferDelay() external onlyOwner returns (bool){
		transferDelayEnabled = false;
		return true;
	}
	
	function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
		_isExcludedMaxTransactionAmount[updAds] = isEx;
	}
	
	function minimumTokensBeforeSwapAmount() external view returns (uint256) {
		return minimumTokensBeforeSwap;
	}
	
	function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
		require(pair != uniswapV2Pair, "The pair cannot be removed");

		_setAutomatedMarketMakerPair(pair, value);
	}

	function _setAutomatedMarketMakerPair(address pair, bool value) private {
		automatedMarketMakerPairs[pair] = value;
		if(value){excludeFromReward(pair);}
		if(!value){includeInReward(pair);}
	}
	
	function setProtectionSettings(bool antiGas) external onlyOwner() {
		gasLimitActive = antiGas;
	}
	
	function setGasPriceLimit(uint256 gas) external onlyOwner {
		require(gas >= 75);
		gasPriceLimit = gas * 1 gwei;
	}
	
	function setGasMaxLimit(uint256 gas) external onlyOwner {
		require(gas >= 750000);
		gasMaxLimit = gas * gasPriceLimit;
	}

	function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
		external
		view
		returns (uint256)
	{
		require(tAmount <= _tTotal, "Amount must be less than supply");
		if (!deductTransferFee) {
			(uint256 rAmount, , , , , ) = _getValues(tAmount);
			return rAmount;
		} else {
			(, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
			return rTransferAmount;
		}
	}

	function tokenFromReflection(uint256 rAmount)
		public
		view
		returns (uint256)
	{
		require(
			rAmount <= _rTotal,
			"Amount must be less than total reflections"
		);
		uint256 currentRate = _getRate();
		return rAmount.div(currentRate);
	}

	function excludeFromReward(address account) public onlyOwner {
		require(!_isExcluded[account], "Account is already excluded");
		require(_excluded.length + 1 <= 50, "Cannot exclude more than 50 accounts.");
		if (_rOwned[account] > 0) {
			_tOwned[account] = tokenFromReflection(_rOwned[account]);
		}
		_isExcluded[account] = true;
		_excluded.push(account);
	}

	function includeInReward(address account) public onlyOwner {
		require(_isExcluded[account], "Account is not excluded");
		for (uint256 i = 0; i < _excluded.length; i++) {
			if (_excluded[i] == account) {
				_excluded[i] = _excluded[_excluded.length - 1];
				_tOwned[account] = 0;
				_isExcluded[account] = false;
				_excluded.pop();
				break;
			}
		}
	}
	
	function removeLimits() external onlyOwner returns (bool){
		limitsInEffect = false;
		gasLimitActive = false;
		transferDelayEnabled = false;
		return true;
	}

	function _approve(
		address owner,
		address spender,
		uint256 amount
	) private {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");

		_allowances[owner][spender] = amount;
		emit Approval(owner, spender, amount);
	}

	function _transfer(
		address from,
		address to,
		uint256 amount
	) private {
		require(from != address(0), "ERC20: transfer from the zero address");
		require(to != address(0), "ERC20: transfer to the zero address");
		require(amount > 0, "Transfer amount must be greater than zero");
		
		if(!tradingActive){
			require(_isExcludedFromFee[from] || _isExcludedFromFee[to], "Trading is not active yet.");
		}
		
		if(limitsInEffect){
			if (
				from != owner() &&
				to != owner() &&
				to != address(0) &&
				to != address(0xdead) &&
				!inSwapAndLiquify
			){
				if(from != owner() && to != uniswapV2Pair && block.number == tradingActiveBlock){
					boughtEarly[to] = true;
					emit BoughtEarly(to);
				}
				
				if (gasLimitActive && automatedMarketMakerPairs[from]) {
					require(tx.gasprice <= gasPriceLimit, "Gas price exceeds limit.");
				}
				
				if (transferDelayEnabled){
					if (to != owner() && to != address(uniswapV2Router) && to != address(uniswapV2Pair)){
						require(_holderLastTransferTimestamp[tx.origin] < block.number, "Only one purchase per block allowed.");
						_holderLastTransferTimestamp[tx.origin] = block.number;
					}
				}
				
				if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
					require(amount <= maxTransactionAmount, "Exceeds the maxTransactionAmount.");
					require(amount+balanceOf(to) <= maxWallet, "Max wallet exceeded");
				}
				else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
					require(amount <= maxTransactionAmount, "Sell transfer amount exceeds the maxTransactionAmount.");
				}
				else {
					require(amount+balanceOf(to) <= maxWallet, "Max wallet exceeded");
				}
			}
		}

		uint256 totalTokensToSwap = _liquidityTokensToSwap + _marketingTokensToSwap;
		uint256 contractTokenBalance = balanceOf(address(this));
		bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

		if (
			!inSwapAndLiquify &&
			swapAndLiquifyEnabled &&
			balanceOf(uniswapV2Pair) > 0 &&
			totalTokensToSwap > 0 &&
			!_isExcludedFromFee[to] &&
			!_isExcludedFromFee[from] &&
			automatedMarketMakerPairs[to] &&
			overMinimumTokenBalance
		) {
			swapBack();
		}

		bool takeFee = true;

		if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
			takeFee = false;
			removeAllFee();
			buyOrSellSwitch = TRANSFER;
		} else {
			// Buy
			if (automatedMarketMakerPairs[from]) {
				removeAllFee();
				_taxFee = _buyTaxFee;
				_liquidityFee = _buyLiquidityFee + _buyMarketingFee;
				_burnFee = _buyBurnFee;
				buyOrSellSwitch = BUY;
			} 
			// Sell
			else if (automatedMarketMakerPairs[to]) {
				removeAllFee();
				_taxFee = _sellTaxFee;
				_liquidityFee = _sellLiquidityFee + _sellMarketingFee;
				_burnFee = _sellBurnFee;
				buyOrSellSwitch = SELL;
				if(boughtEarly[from]  && earlyBuyPenaltyEnd <= block.number){
					_taxFee = _taxFee * 5;
					_liquidityFee = _liquidityFee * 5;
				}
			} else {
					require(!boughtEarly[from] || earlyBuyPenaltyEnd <= block.timestamp, "Snipers can't transfer until penalty timeframe is over.");
					removeAllFee();
					buyOrSellSwitch = TRANSFER;
			}
		}
		
		_tokenTransfer(from, to, amount);
		
		restoreAllFee();
	}

	function swapBack() private lockTheSwap {
		uint256 contractBalance = balanceOf(address(this));
		uint256 totalTokensToSwap = _liquidityTokensToSwap + _marketingTokensToSwap;
		
		// Halve the amount of liquidity tokens
		uint256 tokensForLiquidity = _liquidityTokensToSwap / 2;
		uint256 amountToSwapForBNB = contractBalance.sub(tokensForLiquidity);
		
		uint256 initialBNBBalance = address(this).balance;

		swapTokensForBNB(amountToSwapForBNB); 
		
		uint256 bnbBalance = address(this).balance.sub(initialBNBBalance);
		
		uint256 bnbForMarketing = bnbBalance.mul(_marketingTokensToSwap).div(totalTokensToSwap);
		
		uint256 bnbForLiquidity = bnbBalance.sub(bnbForMarketing);
		
		_liquidityTokensToSwap = 0;
		_marketingTokensToSwap = 0;
		
		(bool success,) = address(marketingAddress).call{value: bnbForMarketing}("");
		
		if(tokensForLiquidity > 0){
			addLiquidity(tokensForLiquidity, bnbForLiquidity);
			emit SwapAndLiquify(amountToSwapForBNB, bnbForLiquidity, tokensForLiquidity);
		}
		
		if(address(this).balance > 1e18){
			(success,) = address(marketingAddress).call{value: address(this).balance}("");
		}
	}
	
	function swapTokensForBNB(uint256 tokenAmount) private {
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = uniswapV2Router.WETH();
		_approve(address(this), address(uniswapV2Router), tokenAmount);
		uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
			tokenAmount,
			0, // accept any amount of ETH
			path,
			address(this),
			block.timestamp
		);
	}
	
	function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
		_approve(address(this), address(uniswapV2Router), tokenAmount);
		uniswapV2Router.addLiquidityETH{value: ethAmount}(
			address(this),
			tokenAmount,
			0, // slippage is unavoidable
			0, // slippage is unavoidable
			liquidityAddress,
			block.timestamp
		);
	}

	function _tokenTransfer(
			address sender,
			address recipient,
			uint256 amount
	) private {
		uint256 burnAmount = 0;
		if(sender != owner() && recipient != owner() && sender!= address(this))
		{
			burnAmount = calculateBurnFee(amount);
		}
		if (_isExcluded[sender] && !_isExcluded[recipient]) {
			_transferFromExcluded(sender, recipient, amount - burnAmount);
		} else if (!_isExcluded[sender] && _isExcluded[recipient]) {
			_transferToExcluded(sender, recipient, amount - burnAmount);
		} else if (_isExcluded[sender] && _isExcluded[recipient]) {
			_transferBothExcluded(sender, recipient, amount - burnAmount);
		} else {
			_transferStandard(sender, recipient, amount - burnAmount);
		}

		removeAllFee();

		if(burnAmount > 0) {
			_transferStandard(sender, deadAddress, burnAmount);
		}
		
		restoreAllFee();
	}

	function _transferStandard(
		address sender,
		address recipient,
		uint256 tAmount
	) private {
		(
			uint256 rAmount,
			uint256 rTransferAmount,
			uint256 rFee,
			uint256 tTransferAmount,
			uint256 tFee,
			uint256 tLiquidity
		) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		_takeLiquidity(tLiquidity);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferToExcluded(
		address sender,
		address recipient,
		uint256 tAmount
	) private {
		(
			uint256 rAmount,
			uint256 rTransferAmount,
			uint256 rFee,
			uint256 tTransferAmount,
			uint256 tFee,
			uint256 tLiquidity
		) = _getValues(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		_takeLiquidity(tLiquidity);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferFromExcluded(
		address sender,
		address recipient,
		uint256 tAmount
	) private {
		(
			uint256 rAmount,
			uint256 rTransferAmount,
			uint256 rFee,
			uint256 tTransferAmount,
			uint256 tFee,
			uint256 tLiquidity
		) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		_takeLiquidity(tLiquidity);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _transferBothExcluded(
		address sender,
		address recipient,
		uint256 tAmount
	) private {
		(
			uint256 rAmount,
			uint256 rTransferAmount,
			uint256 rFee,
			uint256 tTransferAmount,
			uint256 tFee,
			uint256 tLiquidity
		) = _getValues(tAmount);
		_tOwned[sender] = _tOwned[sender].sub(tAmount);
		_rOwned[sender] = _rOwned[sender].sub(rAmount);
		_tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
		_takeLiquidity(tLiquidity);
		_reflectFee(rFee, tFee);
		emit Transfer(sender, recipient, tTransferAmount);
	}

	function _reflectFee(uint256 rFee, uint256 tFee) private {
		_rTotal = _rTotal.sub(rFee);
		_tFeeTotal = _tFeeTotal.add(tFee);
	}

	function _getValues(uint256 tAmount)
		private
		view
		returns (
			uint256,
			uint256,
			uint256,
			uint256,
			uint256,
			uint256
		)
	{
		(uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getTValues(tAmount);
		(uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tLiquidity, _getRate());
		return (
			rAmount,
			rTransferAmount,
			rFee,
			tTransferAmount,
			tFee,
			tLiquidity
		);
	}

	function _getTValues(uint256 tAmount)
		private
		view
		returns (
			uint256,
			uint256,
			uint256
		)
	{
		uint256 tFee = calculateTaxFee(tAmount);
		uint256 tLiquidity = calculateLiquidityFee(tAmount);
		uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
		return (tTransferAmount, tFee, tLiquidity);
	}

	function _getRValues(
		uint256 tAmount,
		uint256 tFee,
		uint256 tLiquidity,
		uint256 currentRate
	)
		private
		pure
		returns (
			uint256,
			uint256,
			uint256
		)
	{
		uint256 rAmount = tAmount.mul(currentRate);
		uint256 rFee = tFee.mul(currentRate);
		uint256 rLiquidity = tLiquidity.mul(currentRate);
		uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
		return (rAmount, rTransferAmount, rFee);
	}

	function _getRate() private view returns (uint256) {
		(uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
		return rSupply.div(tSupply);
	}

	function _getCurrentSupply() private view returns (uint256, uint256) {
		uint256 rSupply = _rTotal;
		uint256 tSupply = _tTotal;
		for (uint256 i = 0; i < _excluded.length; i++) {
			if (
				_rOwned[_excluded[i]] > rSupply ||
				_tOwned[_excluded[i]] > tSupply
			) return (_rTotal, _tTotal);
			rSupply = rSupply.sub(_rOwned[_excluded[i]]);
			tSupply = tSupply.sub(_tOwned[_excluded[i]]);
		}
		if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
		return (rSupply, tSupply);
	}

	function _takeLiquidity(uint256 tLiquidity) private {
		if(buyOrSellSwitch == BUY && _liquidityFee > 0){
			_liquidityTokensToSwap += tLiquidity * _buyLiquidityFee / _liquidityFee;
			_marketingTokensToSwap += tLiquidity * _buyMarketingFee / _liquidityFee;
		} else if(buyOrSellSwitch == SELL && _liquidityFee > 0){
			_liquidityTokensToSwap += tLiquidity * _sellLiquidityFee / _liquidityFee;
			_marketingTokensToSwap += tLiquidity * _sellMarketingFee / _liquidityFee;
		}
		uint256 currentRate = _getRate();
		uint256 rLiquidity = (tLiquidity) * currentRate;
		_rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
		if (_isExcluded[address(this)])
			_tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
	}

	function calculateTaxFee(uint256 _amount) private view returns (uint256) {
		return _amount.mul(_taxFee).div(10**2);
	}

	function calculateLiquidityFee(uint256 _amount)
		private
		view
		returns (uint256)
	{
		return _amount.mul(_liquidityFee).div(10**2);
	}
	
	function calculateBurnFee(uint256 _amount) private view returns (uint256) {
		return _amount.mul(_burnFee).div(10**2);
	}

	function removeAllFee() private {
		if (_taxFee == 0 && _liquidityFee == 0 && _burnFee == 0) return;

		_previousTaxFee = _taxFee;
		_previousLiquidityFee = _liquidityFee;
		_previousBurnFee = _burnFee;

		_taxFee = 0;
		_liquidityFee = 0;
		_burnFee = 0;
	}

	function restoreAllFee() private {
		_taxFee = _previousTaxFee;
		_liquidityFee = _previousLiquidityFee;
		_burnFee = _previousBurnFee;
	}

	function isExcludedFromFee(address account) external view returns (bool) {
		return _isExcludedFromFee[account];
	}

	function excludeFromFee(address account) external onlyOwner {
		_isExcludedFromFee[account] = true;
		emit ExcludeFromFee(account);
	}

	function includeInFee(address account) external onlyOwner {
		_isExcludedFromFee[account] = false;
		emit IncludeInFee(account);
	}
	
	function removeBoughtEarly(address account) external onlyOwner {
		boughtEarly[account] = false;
		emit RemovedSniper(account);
	}

	function setBuyFee(uint256 buyTaxFee, uint256 buyLiquidityFee, uint256 buyMarketingFee, uint256 buyBurnFee)
			external
			onlyOwner
	{
		_buyTaxFee = buyTaxFee;
		_buyLiquidityFee = buyLiquidityFee;
		_buyMarketingFee = buyMarketingFee;
		_buyBurnFee = buyBurnFee;
		require(_buyTaxFee + _buyLiquidityFee + _buyMarketingFee + _buyBurnFee <= 20, "Must keep taxes below 20%");
		emit SetBuyFee(buyMarketingFee, buyLiquidityFee, buyTaxFee, buyBurnFee);
	}

	function setSellFee(uint256 sellTaxFee, uint256 sellLiquidityFee, uint256 sellMarketingFee, uint256 sellBurnFee)
			external
			onlyOwner
	{
		_sellTaxFee = sellTaxFee;
		_sellLiquidityFee = sellLiquidityFee;
		_sellMarketingFee = sellMarketingFee;
		_sellBurnFee = sellBurnFee;
		require(_sellTaxFee + _sellLiquidityFee + _sellMarketingFee + _sellBurnFee <= 30, "Must keep taxes below 30%");
		emit SetSellFee(sellMarketingFee, sellLiquidityFee, sellTaxFee, sellBurnFee);
	}


	function setMarketingAddress(address _marketingAddress) external onlyOwner {
		require(_marketingAddress != address(0), "_marketingAddress address cannot be 0");
		marketingAddress = payable(_marketingAddress);
		_isExcludedFromFee[marketingAddress] = true;
		emit UpdatedMarketingAddress(_marketingAddress);
	}
	
	function setLiquidityAddress(address _liquidityAddress) external onlyOwner {
		require(_liquidityAddress != address(0), "_liquidityAddress address cannot be 0");
		liquidityAddress = payable(_liquidityAddress);
		_isExcludedFromFee[liquidityAddress] = true;
		emit UpdatedLiquidityAddress(_liquidityAddress);
	}

	function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
		swapAndLiquifyEnabled = _enabled;
		emit SwapAndLiquifyEnabledUpdated(_enabled);
	}

	function getPairAddress() external view onlyOwner returns (address) {
		return uniswapV2Pair;
	}

	function changeRouterVersion(address _router)
			external
			onlyOwner
			returns (address _pair)
	{
		require(_router != address(0), "_router address cannot be 0");
		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);

		_pair = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
			address(this),
			_uniswapV2Router.WETH()
		);
		if (_pair == address(0)) {
			// Pair doesn't exist
			_pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
				address(this),
				_uniswapV2Router.WETH()
			);
		}
		uniswapV2Pair = _pair;

		// Set the router of the contract variables
		uniswapV2Router = _uniswapV2Router;
		emit UpdatedRouter(_router);
	}

	// To receive ETH from uniswapV2Router when swapping
	receive() external payable {}

	function transferForeignToken(address _token, address _to)
		external
		onlyOwner
		returns (bool _sent)
	{
		require(_token != address(0), "_token address cannot be 0");
		require(_token != address(this), "Can't withdraw native tokens");
		uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
		_sent = IERC20(_token).transfer(_to, _contractBalance);
		emit TransferForeignToken(_token, _contractBalance);
	}
	
}