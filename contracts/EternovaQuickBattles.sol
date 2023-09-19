// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract EternovaQuickBattles is Ownable{
	
	using Counters for Counters.Counter;
	using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _battleIds;

	event BattleStarted(uint indexed id, address indexed creator, address indexed opponent);
	event BattleFinished(uint id, address indexed winner, uint winnerCityLife, uint looserCityLife);

	event RoundStarted(uint indexed id, uint currentRound);	
	event RoundFinished(uint indexed id, uint currentRound);
	
	struct Troop {
		uint attack;
		uint defense;		
	}

	Troop private predator = Troop(40,100);
	Troop private proximusCobra = Troop(200,200);
	Troop private bounty_hunters = Troop(150,50);

	uint constant MAX_ROUNDS = 3;

	uint constant PREDATOR_UNITS = 5;
	uint constant PROXIMUS_COBRA_UNITS = 2;
	uint constant BOUNTY_HUNTERS_UNITS = 3;
	
	uint constant STARTING_LIFE = 500;

	uint constant MAX_UNITS_FIRST_ROUND = 8;
	uint constant MAX_UNITS_SECOND_ROUND = 9;
	uint constant MAX_UNITS_THIRD_ROUND = 10;

	//Round N° => Max units
	mapping(uint => uint) roundMaxUnits;
	
	uint constant FIRST_ROUND = 1;
	uint constant SECOND_ROUND = 2;
	uint constant THIRD_ROUND = 3;

	struct BattleData {
		address creator;
		address opponent;
		uint currentRound;
		address nextMove;
		uint predatorAttackingUnits;
		uint proximusAttackingUnits;
		uint bountyAttackingUnits;
		uint predatorDefendingUnits;
		uint proximusDefendingUnits;
		uint bountyDefendingUnits;
		uint creatorCityLife;
		uint opponentCityLife;
		address winner;
	}

	//BattleId => Data
	mapping (uint => BattleData) private battle;

	//User => [battleId]
	mapping(address => EnumerableSet.UintSet) private userBattle;

	mapping(address => mapping(address => bool)) currentlyFighting;
			
	constructor() {
		roundMaxUnits[1] = MAX_UNITS_FIRST_ROUND;		
		roundMaxUnits[2] = MAX_UNITS_SECOND_ROUND;		
		roundMaxUnits[3] = MAX_UNITS_THIRD_ROUND;		
	}

	function startBattle(address opponent, uint[3] calldata troopsAmount) external returns(uint){
		require(!areCurrentlyFighting(msg.sender, opponent), "Use requestBattle");
		require(troopsAmount[0] <= PREDATOR_UNITS,"Exceeds Predators max");
		require(troopsAmount[1] <= PROXIMUS_COBRA_UNITS,"Exceeds Proximus Cobra max");
		require(troopsAmount[2] <= BOUNTY_HUNTERS_UNITS,"Exceeds Bounty Hunter max");
	
		uint totalTroops = troopsAmount[0] + troopsAmount[1] + troopsAmount[2];
		require(totalTroops <= roundMaxUnits[FIRST_ROUND],"Too many troops!");

		_battleIds.increment();
		
		BattleData memory data = BattleData(
			msg.sender, //Creator
			opponent, //Opponnent
			FIRST_ROUND, //currentRound
			opponent, //NextMove
			troopsAmount[0], //predatorAttackingUnits
			troopsAmount[1], //proximusAttackingUnits
			troopsAmount[2], //bountyAttackingUnits
			0, //predatorDefendingUnits
			0, //proximusDefendingUnits
			0, //bountyDefendingUnits
			STARTING_LIFE, //creatorCityLife
			STARTING_LIFE, //opponentCityLife
			address(0) //Winner
			);

		setBattle(_battleIds.current(), data);
		userBattle[msg.sender].add(_battleIds.current());
		userBattle[opponent].add(_battleIds.current());
		currentlyFighting[msg.sender][opponent] = true;				
		emit RoundStarted(_battleIds.current(), data.currentRound);

		return _battleIds.current();
	}

	//Troops amount for each type [predator, proximusCobra,bounty_hunters]	
	function requestBattle(uint id, uint[3] calldata troopsAmount) external {
		validateBattleData(id, troopsAmount);
		BattleData memory data = getBattleData(id);
		
		data = BattleData(
			data.creator,
			data.opponent,
			data.currentRound, //currentRound
			data.nextMove, //NextMove
			msg.sender == data.creator ? troopsAmount[0] : data.predatorAttackingUnits, //predatorAttackingUnits
			msg.sender == data.creator ? troopsAmount[1] : data.proximusAttackingUnits, //proximusAttackingUnits
			msg.sender == data.creator ? troopsAmount[2] : data.bountyAttackingUnits, //bountyAttackingUnits
			msg.sender == data.opponent ? troopsAmount[0] : data.predatorDefendingUnits, //predatorDefendingUnits
			msg.sender == data.opponent ? troopsAmount[1] : data.proximusDefendingUnits, //proximusDefendingUnits
			msg.sender == data.opponent ? troopsAmount[2] : data.bountyDefendingUnits, //bountyDefendingUnits
			data.creatorCityLife, //creatorCityLife
			data.opponentCityLife, //opponentCityLife
			address(0) //winner
			);

		if (didBothPlayersMoved(data)){
			resolveRound(id, data);
		}else{
			data.nextMove = data.nextMove == data.creator ? data.opponent : data.creator;
			setBattle(id, data);
			emit RoundStarted(id, data.currentRound);
		}
	}

	function didBothPlayersMoved(BattleData memory data) internal pure returns(bool){
		return data.predatorAttackingUnits + data.proximusAttackingUnits + data.bountyAttackingUnits > 0 &&
	data.predatorDefendingUnits + data.proximusDefendingUnits + data.bountyDefendingUnits > 0;
	}

	function validateBattleData(uint id,uint[3] calldata troopsAmount) internal view{
		require(id <= _battleIds.current(),"Battle id doesn't exist");
		BattleData memory data = getBattleData(id);
		require(msg.sender == data.creator || msg.sender == data.opponent,"Can't request this battle");
		require(data.nextMove == msg.sender,"Not your turn!");
		require(troopsAmount[0] <= PREDATOR_UNITS,"Exceeds Predators max");
		require(troopsAmount[1] <= PROXIMUS_COBRA_UNITS,"Exceeds Proximus Cobra max");
		require(troopsAmount[2] <= BOUNTY_HUNTERS_UNITS,"Exceeds Bounty Hunter max");
		
		uint currentRound = data.currentRound;
		uint totalTroops = troopsAmount[0] + troopsAmount[1] + troopsAmount[2];

		require(totalTroops <= roundMaxUnits[currentRound],"Too many troops!");
		require(totalTroops > 0,"Must send troops!");
	}

	function resolveRound (uint id, BattleData memory data) internal {		
		uint creatorCurrentCityLife = data.creatorCityLife;
		uint opponentCurrentCityLife = data.opponentCityLife;
		//Creator
		uint creatorTotalAttack = data.predatorAttackingUnits * predator.attack + data.proximusAttackingUnits * proximusCobra.attack + data.bountyAttackingUnits * bounty_hunters.attack;
		uint creatorTotalDefense = data.predatorAttackingUnits * predator.defense + data.proximusAttackingUnits * proximusCobra.defense + data.bountyAttackingUnits * bounty_hunters.defense;
		//Opponent
		uint opponentTotalAttack = data.predatorDefendingUnits * predator.attack + data.proximusDefendingUnits * proximusCobra.attack + data.bountyDefendingUnits * bounty_hunters.attack;
		uint opponentTotalDefense = data.predatorDefendingUnits * predator.defense + data.proximusDefendingUnits * proximusCobra.defense + data.bountyDefendingUnits * bounty_hunters.defense;

		BattleData memory newData = BattleData(
			data.creator,
			data.opponent,
			data.currentRound, //currentRound
			data.nextMove,
			0, //predatorAttackingUnits
			0, //proximusAttackingUnits
			0, //bountyAttackingUnits
			0, //predatorDefendingUnits
			0, //proximusDefendingUnits
			0, //bountyDefendingUnits
			getRemainingLife(creatorCurrentCityLife, getTotalDamage(opponentTotalAttack, creatorTotalDefense)), //creatorCityLife
			getRemainingLife(opponentCurrentCityLife, getTotalDamage(creatorTotalAttack, opponentTotalDefense)), //opponentCityLife
			address(0) //Winner
		);
		
		if (data.currentRound == THIRD_ROUND){
			address winner = newData.creatorCityLife >= newData.opponentCityLife ? data.creator : data.opponent;
			newData.currentRound = 0;
			newData.nextMove = address(0);
			newData.winner = winner;
			currentlyFighting[data.creator][data.opponent] = false;
			setBattle(id, newData);
			emit RoundFinished(id, data.currentRound);
			emit BattleFinished(id, winner, winner == data.creator ? newData.creatorCityLife : newData.opponentCityLife, winner == data.opponent ? newData.creatorCityLife : newData.opponentCityLife);
		}else{
			newData.currentRound = data.currentRound + 1;
			
			setBattle(id, newData);
			emit RoundFinished(id, data.currentRound);				
		}

	}
	
	function getTotalDamage(uint attack, uint defense) internal pure returns(uint){
		return attack > defense ? attack - defense : 0;
	}
	
	function getRemainingLife(uint currentLife, uint damage) internal pure returns(uint){
		return currentLife > damage ? currentLife - damage : 0;
	}

	function getBattleData(uint id) internal view returns(BattleData memory){
		return battle[id];
	}

	struct PublicBattleData {
		address creator;
		address opponent;
		uint currentRound;
		address nextMove;
		uint predatorUnits;
		uint proximusUnits;
		uint bountyUnits;
		uint cityLife;
		address winner;
	}

	function getPublicBattleData(uint id) external view returns(PublicBattleData memory data){
		require(id <= _battleIds.current(),"Battle id doesn't exist");
		BattleData memory battleData = battle[id];
		require(msg.sender == battleData.creator || msg.sender == battleData.opponent ,"Unauthorized");

		data.creator = battleData.creator;
		data.opponent = battleData.opponent;
		data.currentRound = battleData.currentRound;
		data.nextMove = battleData.nextMove;
		data.predatorUnits = msg.sender == data.creator ? battleData.predatorAttackingUnits : battleData.predatorDefendingUnits;
		data.proximusUnits = msg.sender == data.creator ? battleData.proximusAttackingUnits : battleData.proximusDefendingUnits;
		data.bountyUnits = msg.sender == data.creator ? battleData.bountyAttackingUnits : battleData.bountyDefendingUnits;
		data.cityLife = msg.sender == data.creator ? battleData.creatorCityLife : battleData.opponentCityLife;
		data.winner = battleData.winner;
	}

	function setBattle(uint id,BattleData memory data) internal{
		battle[id] = data;
	}

	struct BattleDataResponse {
		uint battleId;
		address creator;
		address opponent;
		uint currentRound;
		address nextMove;
		address winner;
	}

	function getUserBattleData(address user, uint limit, uint offset) external view returns(BattleDataResponse[] memory){
		require(limit <= 100, "Can't request too many records!");
		EnumerableSet.UintSet storage _ids = userBattle[user];
		uint battleCount = _ids.length() <= 100 ? _ids.length() : 100;
		uint queryLimit = (battleCount > limit && limit != 0 ? limit : battleCount);
		uint responseIndex;
		BattleDataResponse[]memory response = new BattleDataResponse[](queryLimit);
		for (uint i = offset; i < queryLimit; i++){
			uint id = userBattle[user].at(i);
			BattleData memory data = battle[id];
			response[responseIndex] = (
				BattleDataResponse(
					id,
					data.creator,
					data.opponent,
					data.currentRound,
					data.nextMove,
					data.winner
				)
			);
			responseIndex++;
		}

		return response;
	}
	
	function areCurrentlyFighting(address creator, address opponent) internal view returns(bool){
		return currentlyFighting[creator][opponent];
	}

	function getUserBattleCount(address user) external view returns(uint){
		return userBattle[user].length();
	}

}