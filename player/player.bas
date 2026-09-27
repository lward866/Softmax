' GotA reference policy: draft, farm, push, heal, resupply, and finish the god.
' Every GotA host function has a gameplay use here; calls remain conditional.
' Object indices last only for this decision. IDs may be remembered.
' Read the bot guide for units, LOS restrictions, and action error constants.
' Abilities and items are used only by our explicit policy commands.
' v8 adds spell gates (GotA Spell Use Card, current-game ranges): E and R only
' on enemy heroes, delayed E/R need two heroes or one at 40% HP, W on footmen
' only with no hero in range, R tried first, no casts on buildings.
' v7 replaces lane choice with live lane buckets built from allied towers and
' barracks (GotA v6 frame spec): stay while the committed lane has allied
' footmen; after 48 dry ticks walk once to a less crowded lane that has them.
' v5 adds positional play from "Give this to Claude Code" (Policy items only,
' adapted to the current game): wave following, wave-cover tower rules,
' pressure-based retreat to the nearest allied tower, per-hero HP gates, and
' position/activity notes in the private player log.

dim owned(22)
dim laneGrid(899)
dim anchorX(11)
dim anchorY(11)
dim anchorLane(11)
dim laneAnchorFront(3)
dim laneAnchorRear(3)
dim frontAnchorX(3)
dim frontAnchorY(3)
dim rearAnchorX(3)
dim rearAnchorY(3)
dim laneHeroes(3)
dim laneCreeps(3)
dim laneFront(3)
dim laneFrontX(3)
dim laneFrontY(3)
' Allied hero positions: x at 2 * i, y at 2 * i + 1.
dim allyXY(19)
dim inventorySlot(22)
dim allyIds(9)
dim seenMaxHp(9)
dim foeId(4)
dim foeX(4)
dim foeY(4)
dim foeHp(4)
dim foeClass(4)
dim foeGap(4)
' Cast log per slot: index slot * 4 + 0 hero, 1 creep, 2 other, 3 self.
dim castLog(15)
dim castRange(3)
dim castDelay(3)
dim castGround(3)
dim castMinimum(3)

sub chooseHero()
  if draftTurnId <> selfId then
    exit sub
  end if
  bestClass = -1
  bestScore = -10000
  for candidate = 0 to 9
    if heroAvailable(candidate) then
      role = heroRole(candidate)
      score = 100
      for player = 0 to draftPlayerCount() - 1
        if draftPlayerTeam(player) = selfTeam then
          picked = draftedClass(draftPlayerId(player))
          if picked >= 0 then
            if heroRole(picked) = role then
              score = score - 100
            end if
          end if
        end if
      next player
      if score > bestScore then
        bestScore = score
        bestClass = candidate
      end if
    end if
  next candidate
  if bestClass >= 0 then
    accepted = draftHero(bestClass)
    actionError = lastActionError()
  end if
end sub

sub learnAbilities()
  ' Rank requirements and effects come from the host, not a stat table.
  for upgrade = 1 to 4
    if abilityPoints() = 0 then
      exit sub
    end if
    upgradeSlot = -1
    upgradeScore = -1
    for spellSlot = 0 to 3
      rank = abilityLevel(spellSlot)
      if rank < abilityMaxLevel(spellSlot) then
        if selfLevel >= abilityRequiredLevel(spellSlot) then
          if canLevelAbility(spellSlot) then
            ' Prefer R, W, E, Q whenever the next rank is legal.
            score = spellSlot
            if spellSlot = 1 then
              score = 2
            elseif spellSlot = 2 then
              score = 1
            end if
            if score > upgradeScore then
              upgradeScore = score
              upgradeSlot = spellSlot
            end if
          end if
        end if
      end if
    next spellSlot
    if upgradeSlot < 0 then
      exit sub
    end if
    accepted = levelAbility(upgradeSlot)
    actionError = lastActionError()
  next upgrade
end sub

' Lane ids: 1 A (own-half edge left of our god), 2 middle, 3 B (own-half edge
' above our god), 0 unknown. An allied lane building is labeled by its bearing
' from our god; its point mirror covers the enemy half with A and B swapped.
sub addAnchor(ax, ay)
  bearingX = homeX - ax
  bearingY = ay - homeY
  if bearingX * bearingX + bearingY * bearingY <= 64 then
    exit sub
  end if
  label = 2
  if bearingY * 5 < bearingX * 2 then
    label = 1
  elseif bearingX * 5 < bearingY * 2 then
    label = 3
  end if
  ' Keep only each lane's most forward and rearmost allied building.
  ax2 = ax - enemyX
  ay2 = ay - enemyY
  forward = ax2 * ax2 + ay2 * ay2
  if forward < laneAnchorFront(label) then
    laneAnchorFront(label) = forward
    frontAnchorX(label) = ax
    frontAnchorY(label) = ay
  end if
  if forward > laneAnchorRear(label) then
    laneAnchorRear(label) = forward
    rearAnchorX(label) = ax
    rearAnchorY(label) = ay
  end if
end sub

' Turn the per-lane front/rear buildings and their point mirrors into anchors.
sub buildAnchors()
  anchorsBuilt = 1
  anchorCount = 0
  for label = 1 to 3
    if laneAnchorRear(label) >= 0 then
      anchorX(anchorCount) = frontAnchorX(label)
      anchorY(anchorCount) = frontAnchorY(label)
      anchorLane(anchorCount) = label
      anchorX(anchorCount + 1) = rearAnchorX(label)
      anchorY(anchorCount + 1) = rearAnchorY(label)
      anchorLane(anchorCount + 1) = label
      anchorX(anchorCount + 2) = mapWidth - 1 - frontAnchorX(label)
      anchorY(anchorCount + 2) = mapHeight - 1 - frontAnchorY(label)
      anchorLane(anchorCount + 2) = 4 - label
      anchorX(anchorCount + 3) = mapWidth - 1 - rearAnchorX(label)
      anchorY(anchorCount + 3) = mapHeight - 1 - rearAnchorY(label)
      anchorLane(anchorCount + 3) = 4 - label
      anchorCount = anchorCount + 4
    end if
  next label
end sub

' Bucket a point into the lane of its nearest anchor.
sub laneOfPoint(px, py)
  if anchorsBuilt = 0 then
    buildAnchors()
  end if
  laneId = 0
  nearest = 1000000
  for anchor = 0 to anchorCount - 1
    ax = anchorX(anchor) - px
    ay = anchorY(anchor) - py
    gap = ax * ax + ay * ay
    if gap < nearest then
      nearest = gap
      laneId = anchorLane(anchor)
    end if
  next anchor
end sub

sub readObject(index)
  id = objectId(index)
  kind = objectKind(index)
  team = objectTeam(index)
  hp = objectHp(index)
  if hp <= 0 then
    exit sub
  end if
  x = originX + side * objectX(index)
  y = originY + side * objectY(index)
  dx = x - myX
  dy = y - myY
  distance = dx * dx + dy * dy
  if kind = 6 then
    ' Camps never distract from lane combat or count as enemy heroes.
    if objectReturning(index) or objectAlive(index) = 0 then
      exit sub
    end if
    camp = objectCamp(index)
    tier = campTier(camp)
    campDx = originX + side * campX(camp) - myX
    campDy = originY + side * campY(camp) - myY
    if campDx * campDx + campDy * campDy > 100 then
      exit sub
    end if
    enoughHealth = selfHp * 10 >= selfMaxHp * 7
    if selfTarget = id then
      enoughHealth = selfHp * 10 >= selfMaxHp * 4
    end if
    if camp >= 0 and camp < campCount() and enoughHealth then
      if selfLevel >= 1 + (tier - 1) * 3 and distance <= 64 then
        score = 100 - distance
        if objectLeader(index) then
          score = score - 10
        end if
        if selfTarget = id then
          score = score + 100
        end if
        if score > campScore then
          campScore = score
          campIndex = index
          campId = id
          campHp = hp
          campXpos = x
          campYpos = y
          campDistance = distance
        end if
      end if
    end if
    exit sub
  end if
  if team = selfTeam then
    if kind = 1 then
      homeX = x
      homeY = y
      enemyX = mapWidth - 1 - x
      enemyY = mapHeight - 1 - y
    elseif kind = 5 then
      addAnchor(x, y)
    elseif kind = 4 then
      addAnchor(x, y)
      if distance < safeDistance then
        safeDistance = distance
        safeX = x
        safeY = y
      end if
      ' Protected allied towers still serve as portal anchors.
      dx = x - enemyX
      dy = y - enemyY
      score = dx * dx + dy * dy
      if score < forwardDistance then
        forwardDistance = score
        forwardX = x
        forwardY = y
      end if
    elseif kind = 2 then
      allyIds(allies) = id
      allies = allies + 1
      class = objectClass(index)
      if hp > seenMaxHp(class) then
        seenMaxHp(class) = hp
      end if
      if distance <= 100 then
        friendlyPower = friendlyPower + objectLevel(index) + 2
      end if
      if distance <= 36 then
        allyHeroesNear = allyHeroesNear + 1
      end if
      if id <> selfId and allyCount < 10 then
        allyXY(allyCount * 2) = x
        allyXY(allyCount * 2 + 1) = y
        allyCount = allyCount + 1
        dx = x - homeX
        dy = y - homeY
        if dx * dx + dy * dy > 400 then
          if gridReady then
            laneId = laneGrid((y \ 4) * gridW + x \ 4)
          else
            laneOfPoint(x, y)
          end if
          laneHeroes(laneId) = laneHeroes(laneId) + 1
        end if
      end if
      missing = seenMaxHp(class) - hp
      if distance <= healRange * healRange and missing > healMissing then
        healMissing = missing
        healId = id
      end if
    elseif kind = 3 then
      if distance <= 64 then
        tanks = tanks + 1
      end if
      if distance <= 36 then
        allyCreepsNear = allyCreepsNear + 1
      end if
      if hostDistance < 1000000 and distance <= 400 then
        dx = x - hostX
        dy = y - hostY
        if dx * dx + dy * dy < coverGap then
          coverGap = dx * dx + dy * dy
        end if
      end if
      if gridReady then
        laneId = laneGrid((y \ 4) * gridW + x \ 4)
        laneCreeps(laneId) = laneCreeps(laneId) + 1
        dx = x - enemyX
        dy = y - enemyY
        if dx * dx + dy * dy < laneFront(laneId) then
          laneFront(laneId) = dx * dx + dy * dy
          laneFrontX(laneId) = x
          laneFrontY(laneId) = y
        end if
      end if
      ' The wave front is the allied creep within 20 tiles closest to the enemy god.
      if distance <= 400 then
        dx = x - enemyX
        dy = y - enemyY
        front = dx * dx + dy * dy
        if front < waveScore then
          waveScore = front
          waveX = x
          waveY = y
        end if
      end if
    end if
    exit sub
  end if
  if kind = 1 then
    enemyX = x
    enemyY = y
  end if
  if kind = 4 and objectAlive(index) and distance < hostDistance then
    hostDistance = distance
    hostX = x
    hostY = y
  end if
  if kind = 2 and distance <= 36 then
    enemyHeroesNear = enemyHeroesNear + 1
  end if
  if kind = 2 and foes < 5 and objectAlive(index) then
    foeId(foes) = id
    foeX(foes) = x
    foeY(foes) = y
    foeHp(foes) = hp
    foeClass(foes) = objectClass(index)
    foeGap(foes) = distance
    if hp > seenMaxHp(objectClass(index)) then
      seenMaxHp(objectClass(index)) = hp
    end if
    foes = foes + 1
  end if
  if kind = 2 and distance <= 144 then
    enemyPower = enemyPower + objectLevel(index) + 2
    if objectMana(index) >= 25 and objectSilenceTicks(index) = 0 then
      enemyPower = enemyPower + 2
    end if
  end if
  if distance < threatDistance then
    threatDistance = distance
    threatX = x
    threatY = y
  end if
  if distance > 324 or objectAlive(index) = 0 then
    exit sub
  end if
  target = objectTarget(index)
  if kind = 4 and target = selfId then
    towerAggro = 1
  end if
  ' Engage gate: below the hero's HP gate, only take heroes that are finishable.
  if kind = 2 and hpPct < engagePct and hp >= selfAttackDamage * 4 then
    exit sub
  end if
  ' Let allied creeps tank buildings first; take the god only with allied presence.
  if kind = 4 or kind = 5 then
    if coverCreeps = 0 and target <> selfId then
      exit sub
    end if
  elseif kind = 1 then
    if coverCreeps = 0 and coverHeroes = 0 then
      exit sub
    end if
  end if
  score = 1000 - distance * 2
  if kind = 1 then
    score = score + 500
  elseif kind = 2 then
    score = score + 60 - objectLevel(index) * 8
    if hp < selfAttackDamage * 4 then
      score = score + 250
    end if
  elseif kind = 3 then
    score = score + 100
    if hp <= selfAttackDamage and selfAttackCooldown <= tickRate \ 2 then
      score = score + 400
    end if
  elseif kind = 5 then
    score = score + 40
  end if
  if target = selfId then
    score = score + 40
  end if
  if id = selfTarget then
    score = score + 60
  end if
  if id = blockedId and worldTick < blockedUntil then
    exit sub
  end if
  if score > bestScore then
    bestScore = score
    bestIndex = index
    bestId = id
    bestKind = kind
    bestHp = hp
    bestX = x
    bestY = y
    bestDistance = distance
  end if
end sub

sub observe()
  campScore = -10000
  campId = 0
  bestScore = -10000
  bestId = 0
  bestDistance = 1000000
  threatDistance = 1000000
  forwardDistance = 1000000
  safeDistance = 1000000
  waveScore = 1000000
  foes = 0
  anchorCount = 0
  anchorsBuilt = 0
  allyCount = 0
  bucketed = 0
  hostDistance = 1000000
  coverGap = 1000000
  for laneReset = 0 to 3
    laneHeroes(laneReset) = 0
    laneCreeps(laneReset) = 0
    laneFront(laneReset) = 1000000
    laneAnchorFront(laneReset) = 1000000
    laneAnchorRear(laneReset) = -1
  next laneReset
  ' Enemy buildings are scanned before allied heroes and creeps, so the cover
  ' gates in readObject use the previous decision's counts.
  coverCreeps = allyCreepsNear
  coverHeroes = allyHeroesNear
  allyCreepsNear = 0
  allyHeroesNear = 0
  enemyHeroesNear = 0
  friendlyPower = 0
  enemyPower = 0
  allies = 0
  tanks = 0
  towerAggro = 0
  healId = selfId
  healMissing = selfMaxHp - selfHp
  seenMaxHp(selfClass) = selfMaxHp
  objects = objectCount()
  hpPct = 0
  if selfMaxHp > 0 then
    hpPct = selfHp * 100 \ selfMaxHp
  end if
  ' Buildings and heroes precede creeps. Rotate the large creep tail so a
  ' crowded battlefield cannot exhaust the per-decision VM budget.
  for scan = 0 to 95
    index = scan
    if scan >= 48 then
      index = scan + scanOffset
    end if
    if index < objects then
      readObject(index)
    end if
  next scan
  ' Retain a creep target outside this scan window only after validating
  ' its remembered index against the stable ID in the fresh observation.
  if targetIndex >= 48 and targetIndex < objects and selfTarget <> 0 then
    if targetIndex < 48 + scanOffset or targetIndex >= 96 + scanOffset then
      if objectId(targetIndex) = selfTarget then
        readObject(targetIndex)
      end if
    end if
  end if
  scanOffset = scanOffset + 48
  if scanOffset >= objects - 48 then
    scanOffset = 0
  end if
  if bestId = 0 and campId <> 0 and towerAggro = 0 and enemyPower = 0 then
    bestId = campId
    bestIndex = campIndex
    bestKind = 6
    bestHp = campHp
    bestX = campXpos
    bestY = campYpos
    bestDistance = campDistance
  end if
  if bestId = 0 then
    exit sub
  end if
  targetIndex = bestIndex
  ' Divide large integer world units before mixing them with Q16.16 values.
  velocityX = (side * objectVelX(bestIndex) \ 100) / (worldScale \ 100)
  velocityY = (side * objectVelY(bestIndex) \ 100) / (worldScale \ 100)
  ' Do not lead a unit whose control lasts through the predicted impact.
  targetHeld = objectStunTicks(bestIndex)
  targetRoot = objectRootTicks(bestIndex)
  if targetRoot > targetHeld then
    targetHeld = targetRoot
  end if
  facingX = (side * objectFacingX(bestIndex) \ 100) / (worldScale \ 100)
  facingY = (side * objectFacingY(bestIndex) \ 100) / (worldScale \ 100)
  aimedAtUs = facingX * (myX - bestX) + facingY * (myY - bestY)
  if bestKind = 2 then
    ' Visible equipment and potion stacks help judge a close duel.
    for inspectSlot = 0 to 5
      gear = objectItemId(bestIndex, inspectSlot)
      quantity = objectItemCount(bestIndex, inspectSlot)
      if quantity > 0 and bestDistance <= 144 then
        if gear >= 5 and gear <= 20 then
          enemyPower = enemyPower + 1
        elseif gear = 1 or gear = 2 then
          enemyPower = enemyPower + 2
        end if
      end if
    next inspectSlot
  end if
end sub

sub buy(id, price, quantity)
  if owned(id) >= quantity or budget < price then
    exit sub
  end if
  if owned(id) = 0 and emptySlots = 0 then
    exit sub
  end if
  accepted = buyItem(id)
  actionError = lastActionError()
  if accepted then
    if owned(id) = 0 then
      emptySlots = emptySlots - 1
    end if
    owned(id) = owned(id) + 1
    budget = budget - price
    for boughtSlot = 0 to 5
      if itemId(boughtSlot) = id then
        inventorySlot(id) = boughtSlot
      end if
    next boughtSlot
  end if
end sub

sub inventory()
  for id = 0 to 22
    owned(id) = 0
    inventorySlot(id) = -1
  next id
  emptySlots = 0
  for itemSlot = 0 to 5
    id = itemId(itemSlot)
    if id = 0 then
      emptySlots = emptySlots + 1
    else
      owned(id) = itemCount(itemSlot)
      inventorySlot(id) = itemSlot
      if itemCooldown(itemSlot) = 0 and inOwnSpawn() = 0 then
        consume = 0
        if id = 1 and selfMaxHp - selfHp >= 120 and selfHp * 10 <= selfMaxHp * 6 then
          consume = threatDistance > 100 and worldTick - hurtTick > tickRate
        elseif id = 2 and selfMaxHp - selfHp >= 90 and selfHp * 100 <= selfMaxHp * 45 then
          consume = 1
        elseif id = 2 and selfMaxHp - selfHp >= 60 and selfHp * 10 <= selfMaxHp * 6 then
          consume = enemyHeroesNear > 0 or towerAggro
        elseif id = 22 and selfMaxMana - selfMana >= 45 then
          consume = threatDistance > 100 and worldTick - hurtTick > tickRate
        elseif id = 3 and selfMana * 3 < selfMaxMana then
          consume = bestId <> 0
        elseif id = 4 and selfTarget = bestId and bestId <> 0 and bestKind = 2 then
          consume = bestDistance <= attackRange * attackRange
        end if
        if consume then
          accepted = useItem(itemSlot)
          actionError = lastActionError()
          if accepted then
            owned(id) = owned(id) - 1
            if owned(id) = 0 then
              emptySlots = emptySlots + 1
              inventorySlot(id) = -1
            end if
          end if
        end if
      end if
    end if
  next itemSlot
  if canShop() = 0 then
    exit sub
  end if
  ' Reserve three slots for recovery and travel, two for useful equipment,
  ' and one for a role-specific burst consumable. Stacks top up on return.
  budget = selfGold
  buy(8, 100, 1)
  buy(1, 30, 2)
  buy(21, 100, 2)
  buy(22, 45, 2)
  if role = 0 or role = 4 then
    buy(16, 160, 1)
    buy(2, 75, 2)
  elseif role = 1 then
    buy(19, 180, 1)
    buy(4, 40, 2)
  else
    buy(20, 190, 1)
    buy(3, 90, 2)
  end if
end sub

sub dodgeWarnings()
  dodge = 0
  warnings = spellCount()
  ' Rotate unusually busy spell lists instead of starving later warnings.
  for warning = warningOffset to warningOffset + 11
    if warning < warnings then
      spell = spellAbility(warning)
      caster = spellCasterId(warning)
      hostile = caster <> selfId
      for ally = 0 to allies - 1
        if caster = allyIds(ally) then
          hostile = 0
        end if
      next ally
      ' Recovery effects are harmless, including those with hidden casters.
      if spell = 0 or spell = 2 or spell = 8 or spell = 12 then
        hostile = 0
      end if
      if spell = 13 or spell = 14 or spell = 16 or spell = 20 then
        hostile = 0
      end if
      if spell = 32 or spell = 36 then
        hostile = 0
      end if
      impact = spellImpactTick(warning) - worldTick
      warningX = originX + side * spellX(warning)
      warningY = originY + side * spellY(warning)
      dx = myX - warningX
      dy = myY - warningY
      if hostile and impact > 0 and impact <= tickRate * 3 then
        if dx * dx + dy * dy <= 9 then
          dodge = 1
          dodgeX = myX + 3
          dodgeY = myY + 3
          if dx < 0 then
            dodgeX = myX - 3
          end if
          if dy < 0 then
            dodgeY = myY - 3
          end if
        end if
      end if
    end if
  next warning
  warningOffset = warningOffset + 12
  if warningOffset >= warnings then
    warningOffset = 0
  end if
end sub

sub moveTo(goalX, goalY, marching)
  if selfRootTicks > 0 then
    exit sub
  end if
  if goalX = orderX and goalY = orderY and marching = orderMarch then
    if worldTick - orderTick < tickRate * 2 then
      exit sub
    end if
  end if
  ' Snap the requested destination to an open nearby surface. A* in the
  ' host still owns the complete route and cliff/ramp collision checks.
  routeScore = 1000000
  routeFound = 0
  floorHeight = terrainHeight(selfX, selfY)
  for offsetY = -1 to 1
    for offsetX = -1 to 1
      tileX = goalX + offsetX
      tileY = goalY + offsetY
      worldTileX = originX + side * tileX
      worldTileY = originY + side * tileY
      if tileX >= 0 and tileX < mapWidth then
        if tileY >= 0 and tileY < mapHeight then
          open = terrainWalkable(worldTileX, worldTileY)
          ground = terrainKind(worldTileX, worldTileY)
          height = terrainHeight(worldTileX, worldTileY)
          depth = terrainWaterDepth(worldTileX, worldTileY)
          if open = 0 then
            for layer = 0 to mapLayers - 1
              worldLayer = layer
              if layer = RedFortLayer or layer = BlueFortLayer then
                worldLayer = layer + selfTeam * (RedFortLayer + BlueFortLayer - 2 * layer)
              end if
              if terrainWalkableAt(worldTileX, worldTileY, worldLayer) then
                open = 1
                ground = terrainKindAt(worldTileX, worldTileY, worldLayer)
                height = terrainHeightAt(worldTileX, worldTileY, worldLayer)
                depth = terrainWaterDepthAt(worldTileX, worldTileY, worldLayer)
                exit for
              end if
            next layer
          end if
          if open and ground <> TerrainNone then
            elevation = height - floorHeight
            if elevation < 0 then
              elevation = -elevation
            end if
            score = (offsetX * offsetX + offsetY * offsetY) * 20
            score = score + depth * 2 + elevation
            if ground = TerrainRoad then
              score = score - 5
            end if
            if score < routeScore then
              routeScore = score
              routeX = tileX
              routeY = tileY
              routeFound = 1
            end if
          end if
        end if
      end if
    next offsetX
  next offsetY
  if routeFound = 0 then
    exit sub
  end if
  if marching then
    accepted = attackMove(originX + side * routeX, originY + side * routeY)
  else
    accepted = walkTo(originX + side * routeX, originY + side * routeY)
  end if
  actionError = lastActionError()
  orderTick = worldTick
  if accepted then
    orderX = goalX
    orderY = goalY
    orderMarch = marching
  elseif actionError = ActionNoRoute then
    ' Try the lane center on the next decision rather than retrying a wall.
    crossedMiddle = 0
    blockedId = bestId
    blockedUntil = worldTick + tickRate * 3
  end if
end sub

sub spells()
  if selfSilenceTicks > 0 then
    exit sub
  end if
  ' R first, then E, W, Q: an ultimate with a legal hero shot is spent now.
  for slotOrder = 0 to 3
    spellSlot = 3 - slotOrder
    charges = abilityCharges(spellSlot)
    recharge = abilityRecharge(spellSlot)
    damage = abilityDamage(spellSlot)
    healing = abilityHeal(spellSlot)
    restore = abilityRestore(spellSlot)
    cost = abilityManaCost(spellSlot)
    if abilityLevel(spellSlot) > 0 and charges > 0 then
      if abilityCooldown(spellSlot) = 0 and selfMana >= cost then
        castId = 0
        castKind = 0
        if healing > 0 and healMissing * 10 >= healing * 7 then
          ' Heals only when at least 70% of the packet will land.
          if selfClass = DruidWarden and spellSlot > 0 then
            castId = healId
          elseif selfClass = VanguardKnight and spellSlot = 2 then
            ' Aegis heals around us, even when only an ally is wounded.
            castId = selfId
          elseif (selfMaxHp - selfHp) * 10 >= healing * 7 then
            castId = selfId
          end if
          castKind = 7
        elseif restore > 0 and selfMaxMana - selfMana >= restore then
          castId = selfId
          castKind = 7
        elseif damage > 0 then
          ' Nearest visible enemy hero inside this slot's cast range.
          heroPick = -1
          reach = castRange(spellSlot) * castRange(spellSlot)
          for foe = 0 to foes - 1
            if foeGap(foe) <= reach and foeGap(foe) >= castMinimum(spellSlot) * castMinimum(spellSlot) then
              if heroPick < 0 then
                heroPick = foe
              elseif foeGap(foe) < foeGap(heroPick) then
                heroPick = foe
              end if
            end if
          next foe
          if heroPick >= 0 and spellSlot >= 2 and castDelay(spellSlot) >= tickRate then
            ' A delayed area needs two heroes near the aim or a low target.
            crowd = 0
            for foe = 0 to foes - 1
              dx = foeX(foe) - foeX(heroPick)
              dy = foeY(foe) - foeY(heroPick)
              if dx * dx + dy * dy <= 4 then
                crowd = crowd + 1
              end if
            next foe
            if crowd < 2 and foeHp(heroPick) * 10 > seenMaxHp(foeClass(heroPick)) * 4 then
              heroPick = -1
            end if
          end if
          if heroPick >= 0 then
            castId = foeId(heroPick)
            castKind = 2
            castX = foeX(heroPick)
            castY = foeY(heroPick)
          elseif spellSlot <= 1 and bestId <> 0 and bestKind <> 1 and bestKind <> 4 and bestKind <> 5 then
            ' Q and W may farm footmen or camps when no hero is in range.
            if bestDistance <= reach and bestDistance >= castMinimum(spellSlot) * castMinimum(spellSlot) then
              ' Save the last recharging charge for valuable targets.
              if bestKind <> 3 or charges > 1 or recharge <= tickRate or bestHp <= damage then
                castId = bestId
                castKind = bestKind
                castX = bestX
                castY = bestY
              end if
            end if
          elseif spellSlot = 3 then
            heldR = heldR + 1
          end if
        end if
        if castId <> 0 then
          accepted = 0
          if castId <> selfId and castGround(spellSlot) then
            ' No velocity lead: aim at the target's current tile.
            if castX >= 0 and castX < mapWidth - 1 and castY >= 0 and castY < mapHeight - 1 then
              accepted = castPoint(spellSlot, originX + side * castX, originY + side * castY)
              actionError = lastActionError()
            end if
          end if
          ' Targeted projectiles track their target. Targeted ground rings
          ' offset their center so the enemy is inside the damaging band.
          if accepted = 0 then
            accepted = castTarget(spellSlot, castId)
            actionError = lastActionError()
          end if
          if accepted then
            if castKind = 7 then
              castLog(spellSlot * 4 + 3) = castLog(spellSlot * 4 + 3) + 1
            elseif castKind = 2 then
              castLog(spellSlot * 4 + 0) = castLog(spellSlot * 4 + 0) + 1
            elseif castKind = 3 or castKind = 6 then
              castLog(spellSlot * 4 + 1) = castLog(spellSlot * 4 + 1) + 1
            else
              castLog(spellSlot * 4 + 2) = castLog(spellSlot * 4 + 2) + 1
            end if
            exit sub
          end if
        end if
      end if
    end if
  next slotOrder
end sub

if drafting then
  chooseHero()
  end
end if

' Diagnostics only: a status line every 30 simulated seconds for the private player log.
if worldTick >= nextLog then
  nextLog = worldTick + tickRate * 30
  ' Team-relative position: lane is from the own-base diagonal (A = x-low
  ' side lane, B = y-high side lane, M = middle); push grows toward the enemy god.
  print "STATUS t="; worldTick \ tickRate; " class="; selfClass; " lvl="; selfLevel; " hp="; selfHp; "/"; selfMaxHp; " mana="; selfMana; " gold="; selfGold; " deaths="; selfDeaths; " respawn="; selfRespawnTicks \ tickRate; " hits="; selfAttacksLanded; " x="; selfX; " y="; selfY; " retreat="; retreating; " spawn="; inOwnSpawn()
  print "POS t="; worldTick \ tickRate; " tx="; myX; " ty="; myY; " lane="; myLane; " committed="; committedLane; " heroesA="; laneHeroes(1); " heroesM="; laneHeroes(2); " heroesB="; laneHeroes(3); " creepsA="; laneCreeps(1); " creepsM="; laneCreeps(2); " creepsB="; laneCreeps(3); " rotate="; rotateReason$; " push="; myY - myX; " allyCreeps="; allyCreepsNear; " allyHeroes="; allyHeroesNear; " enemyHeroes="; enemyHeroesNear; " towerAggro="; towerAggro; " wave="; waveScore < 1000000; " why="; retreatReason
  print "LANE t="; worldTick \ tickRate; " lock="; lockId; " lockAge="; worldTick - lockSince; " shareSum="; shareSum; " shareN="; shareN; " coverSum="; coverSum; " coverN="; coverN; " lockAgeSum="; lockAgeSum; " lockN="; lockN; " dryTicks="; dryTicks; " rotations="; rotations; " clockTax="; (worldTick \ tickRate) * 10 \ 3
  shareSum = 0
  shareN = 0
  coverSum = 0
  coverN = 0
  lockAgeSum = 0
  lockN = 0
  print "ACT t="; worldTick \ tickRate; " fightHero="; actHero; " fightCreep="; actCreep; " fightBuilding="; actBuilding; " fightCamp="; actCamp; " march="; actMarch; " followWave="; actWave; " retreat="; actRetreat; " spawnWait="; actSpawn; " dodge="; actDodge; " towerStep="; actTower; " backOff="; actBack; " dead="; actDead
  actHero = 0
  actCreep = 0
  actBuilding = 0
  actCamp = 0
  actMarch = 0
  actWave = 0
  actRetreat = 0
  actSpawn = 0
  actDodge = 0
  actTower = 0
  actBack = 0
  actDead = 0
end if

' The spell note prints 15 seconds apart from the other notes because each
' BASIC run has a print-event budget.
if nextCastLog = 0 then
  nextCastLog = worldTick + tickRate * 15
end if
if worldTick >= nextCastLog then
  nextCastLog = worldTick + tickRate * 30
  print "CAST t="; worldTick \ tickRate; " qHero="; castLog(0); " qCreep="; castLog(1); " qOther="; castLog(2); " qSelf="; castLog(3); " wHero="; castLog(4); " wCreep="; castLog(5); " wOther="; castLog(6); " wSelf="; castLog(7); " eHero="; castLog(8); " eCreep="; castLog(9); " eOther="; castLog(10); " eSelf="; castLog(11); " rHero="; castLog(12); " rCreep="; castLog(13); " rOther="; castLog(14); " rSelf="; castLog(15); " heldR="; heldR
  for castReset = 0 to 15
    castLog(castReset) = 0
  next castReset
  heldR = 0
end if

' Buy back immediately whenever affordable, including during a long respawn.
if selfHp <= 0 then
  if worldTick >= nextDeadTick then
    nextDeadTick = worldTick + 6
    actDead = actDead + 1
  end if
  price = buybackPrice()
  if price > 0 and selfGold >= price then
    accepted = buyback()
    actionError = lastActionError()
  end if
  initialized = 0
  end
end if
if selfChannelTicks > 0 or selfStunTicks > 0 then
  end
end if
if worldTick < nextThink then
  end
end if
' Use the same team-relative coordinates for every spatial decision.
side = 1 - selfTeam * 2
originX = selfTeam * (mapWidth - 1)
originY = selfTeam * (mapHeight - 1)
myX = originX + side * selfX
myY = originY + side * selfY

nextThink = worldTick + 6
role = heroRole(selfClass)
attackRange = (selfAttackRange \ 100) / (worldScale \ 100)
speed = (selfMoveSpeed \ 100) / (worldScale \ 100)

if initialized = 0 then
  initialized = 1
  spawnX = myX
  spawnY = myY
  homeX = myX
  homeY = myY
  enemyX = mapWidth - 1 - myX
  enemyY = mapHeight - 1 - myY
  previousHp = selfHp
  progressTick = worldTick
  previousX = myX
  previousY = myY
  crossedMiddle = 0
  retreating = 0
  ' The host exposes effects and costs, but not spell range or cast shape.
  ' These small tables mirror content.nim; all distances are in tiles.
  castRange(0) = 0
  castRange(1) = 1.5
  castRange(2) = 2.5
  castRange(3) = 2
  castDelay(2) = 24
  castDelay(3) = 24
  ' Policy HP gates (percent): retreat with an enemy hero near, retreat under
  ' pressure, re-enter after recovering, and minimum HP to pick hero fights.
  retreatPct = 35
  pressurePct = 50
  reenterPct = 60
  engagePct = 55
  if selfClass = VanguardKnight or selfClass = DeathKnight then
    reenterPct = 65
  end if
  if selfClass = VanguardKnight or selfClass = DemonHunter or selfClass = DeathKnight or selfClass = Berserker then
    engagePct = 60
  end if
  if selfClass = DeathKnight or selfClass = Warlock then
    retreatPct = 30
    pressurePct = 45
  elseif selfClass = Crossbowman then
    retreatPct = 38
  elseif selfClass = DemonHunter then
    retreatPct = 40
  end if
  healRange = 4
  for spellSlot = 0 to 3
    castGround(spellSlot) = spellSlot >= 2
    castMinimum(spellSlot) = 0
  next spellSlot
  if selfClass = VanguardKnight then
    healRange = 7 / 3
    castRange(2) = 7 / 3
    castRange(3) = 11 / 6
    castDelay(2) = 12
    castDelay(3) = 6
  elseif selfClass = Ranger then
    castRange(0) = 7
    castRange(1) = 6
    castRange(2) = 6.5
    castRange(3) = 8
  elseif selfClass = Arcanist then
    castRange(1) = 5.5
    castRange(2) = 6
    castRange(3) = 7
    castDelay(2) = 48
    castDelay(3) = 72
  elseif selfClass = DruidWarden then
    castRange(1) = 4
    castRange(2) = 4
    castRange(3) = 10 / 3
  elseif selfClass = DemonHunter then
    castRange(2) = 2
    castRange(3) = 5
    castDelay(2) = 6
    castGround(3) = 0
  elseif selfClass = DeathKnight then
    castRange(2) = 8 / 3
    castRange(3) = 7 / 3
    castDelay(3) = 12
    castGround(3) = 0
    castMinimum(3) = 2 / 3
  elseif selfClass = Crossbowman then
    castRange(0) = 7
    castRange(1) = 20 / 3
    castRange(2) = 6
    castRange(3) = 7.5
    castDelay(2) = 12
  elseif selfClass = Lich then
    castRange(0) = 6
    castRange(1) = 20 / 3
    castRange(2) = 5
    castRange(3) = 6.5
    castGround(3) = 0
  elseif selfClass = Warlock then
    castRange(1) = 14 / 3
    castRange(2) = 4
    castRange(3) = 5
    castGround(3) = 0
  elseif selfClass = Berserker then
    castRange(3) = 13 / 6
    castDelay(2) = 12
    castDelay(3) = 48
  end if
end if

if selfHp < previousHp then
  hurtTick = worldTick
end if
previousHp = selfHp
if selfAttacksLanded <> previousHits or myX <> previousX or myY <> previousY then
  progressTick = worldTick
end if
previousHits = selfAttacksLanded
previousX = myX
previousY = myY
if worldTick - progressTick > tickRate * 6 and selfTarget <> 0 then
  blockedId = selfTarget
  blockedUntil = worldTick + tickRate * 3
  progressTick = worldTick
end if

learnAbilities()
observe()
' The lane grid caches nearest-anchor buckets in 4-tile cells so every
' footman can be bucketed cheaply. It is rebuilt 3 cells per idle decision (no
' target, no nearby enemy hero) from the live anchors whenever an allied lane
' building falls, keeping busy decisions under the BASIC instruction limit.
gridW = (mapWidth + 3) \ 4
gridH = (mapHeight + 3) \ 4
if gridW * gridH <= 900 and (laneAnchorRear(1) >= 0 or laneAnchorRear(2) >= 0 or laneAnchorRear(3) >= 0) then
  signature = 0
  for label = 1 to 3
    if laneAnchorRear(label) >= 0 then
      signature = signature + (frontAnchorX(label) + frontAnchorY(label) * 3 + rearAnchorX(label) * 7 + rearAnchorY(label) * 11) * label
    end if
  next label
  if signature <> buildSignature then
    buildSignature = signature
    gridCursor = 0
  end if
  if gridCursor < gridW * gridH and enemyHeroesNear = 0 and bestId = 0 then
    for cell = 1 to 3
      if gridCursor < gridW * gridH then
        laneOfPoint((gridCursor - (gridCursor \ gridW) * gridW) * 4 + 2, (gridCursor \ gridW) * 4 + 2)
        laneGrid(gridCursor) = laneId
        gridCursor = gridCursor + 1
      end if
    next cell
    if gridCursor >= gridW * gridH then
      gridReady = 1
    end if
  end if
end if
' Frame-spec metrics: own lane bucket, farm-target sharing, cover, lock age.
myLane = 0
dx = myX - homeX
dy = myY - homeY
if dx * dx + dy * dy > 400 and gridReady then
  myLane = laneGrid((myY \ 4) * gridW + myX \ 4)
end if
if bestId <> 0 then
  share = 0
  for ally = 0 to allyCount - 1
    dx = allyXY(ally * 2) - bestX
    dy = allyXY(ally * 2 + 1) - bestY
    if dx * dx + dy * dy <= 36 then
      share = share + 1
    end if
  next ally
  shareSum = shareSum + share
  shareN = shareN + 1
end if
if hostDistance < 1000000 then
  coverN = coverN + 1
  if coverGap < hostDistance then
    coverSum = coverSum + 1
  end if
end if
if selfTarget <> lockId then
  lockId = selfTarget
  lockSince = worldTick
end if
if lockId <> 0 then
  lockAgeSum = lockAgeSum + worldTick - lockSince
  lockN = lockN + 1
end if
inventory()
spells()
dodgeWarnings()

retreatWhy = 0
if hpPct <= retreatPct and enemyHeroesNear > 0 then
  retreatWhy = 1
elseif hpPct < pressurePct and enemyHeroesNear >= 2 then
  retreatWhy = 2
elseif hpPct < pressurePct and towerAggro and allyCreepsNear = 0 then
  retreatWhy = 3
elseif hpPct <= 20 then
  retreatWhy = 4
elseif bestKind = 6 and hpPct < 40 then
  retreatWhy = 5
end if
if retreatWhy > 0 then
  retreating = 1
  retreatReason = retreatWhy
end if
if retreating and hpPct >= reenterPct and selfMana * 8 >= selfMaxMana then
  retreating = 0
end if
if selfMana * 8 < selfMaxMana and bestId = 0 then
  retreating = 1
end if
if inOwnSpawn() then
  if selfHp * 10 < selfMaxHp * 9 or selfMana * 10 < selfMaxMana * 9 then
    actSpawn = actSpawn + 1
    moveTo(spawnX, spawnY, 0)
    end
  end if
  retreating = 0
end if

if dodge and selfRootTicks = 0 then
  actDodge = actDodge + 1
  moveTo(dodgeX, dodgeY, 0)
  end
end if
if retreating then
  actRetreat = actRetreat + 1
  ' Above 20% HP with a health potion, recover beside the nearest allied tower
  ' instead of crossing the map; spawn remains the fallback.
  if hpPct > 20 and safeDistance < 1000000 and (owned(1) > 0 or owned(2) > 0) then
    if safeDistance > 9 then
      moveTo(safeX, safeY, 0)
      end
    end if
    for potion = 1 to 2
      if owned(potion) > 0 then
        if itemCooldown(inventorySlot(potion)) = 0 and selfHp < selfMaxHp then
          accepted = useItem(inventorySlot(potion))
          actionError = lastActionError()
          if accepted then
            end
          end if
        end if
      end if
    next potion
    if owned(1) + owned(2) > 0 then
      end
    end if
  end if
  ' A safe scroll saves the long return trip; damage and control can punish it.
  if owned(21) > 0 and selfPortalCooldown = 0 and selfRootTicks = 0 then
    dx = myX - homeX
    dy = myY - homeY
    if dx * dx + dy * dy > 400 and threatDistance > 144 then
      accepted = useItemAt(inventorySlot(21), originX + side * spawnX, originY + side * spawnY)
      actionError = lastActionError()
      if accepted then
        end
      end if
    end if
  end if
  moveTo(spawnX, spawnY, 0)
  end
end if

if towerAggro and allyCreepsNear = 0 then
  actTower = actTower + 1
  if safeDistance < 1000000 then
    moveTo(safeX, safeY, 0)
  else
    moveTo(homeX, homeY, 0)
  end if
  end
end if
if enemyPower > friendlyPower + 6 and threatDistance < 64 then
  if selfHp * 4 < selfMaxHp * 3 then
    actBack = actBack + 1
    moveTo(homeX, homeY, 0)
    end
  end if
end if

if bestId <> 0 then
  if bestKind = 2 then
    actHero = actHero + 1
  elseif bestKind = 3 then
    actCreep = actCreep + 1
  elseif bestKind = 6 then
    actCamp = actCamp + 1
  else
    actBuilding = actBuilding + 1
  end if
  ' Finish a windup before kiting; never cancel every swing with movement.
  if bestKind = 2 and aimedAtUs > 0 and attackRange >= 3 then
    if bestDistance < 4 and selfAttackCooldown > tickRate \ 2 then
      if selfAttacksLanded > 0 and speed > 0 then
        kiteStep = (selfMoveSpeed * tickRate) \ worldScale
        if kiteStep < 1 then
          kiteStep = 1
        elseif kiteStep > 4 then
          kiteStep = 4
        end if
        kiteX = myX + kiteStep
        kiteY = myY + kiteStep
        if bestX >= myX then
          kiteX = myX - kiteStep
        end if
        if bestY >= myY then
          kiteY = myY - kiteStep
        end if
        moveTo(kiteX, kiteY, 0)
        end
      end if
    end if
  end if
  if selfTarget <> bestId then
    accepted = attackTarget(bestId)
    actionError = lastActionError()
    if accepted = 0 then
      blockedId = bestId
      blockedUntil = worldTick + tickRate * 3
    else
      orderTick = 0
    end if
  end if
  end
end if

' Ladder step 8, reached only with nothing to dodge, recover, fight or hit.
' First commitment follows the draft role; afterwards stay while the lane has
' allied footmen, and rotate only after 48 dry ticks to a lane with fewer
' allied heroes that still has footmen. Without anchors keep the last lane.
if committedLane = 0 then
  committedLane = 2
  if role = 0 or role = 2 then
    committedLane = 1
  elseif role = 1 or role = 3 then
    committedLane = 3
  end if
  rotateReason$ = "none"
end if
if laneAnchorRear(1) >= 0 or laneAnchorRear(2) >= 0 or laneAnchorRear(3) >= 0 then
  if laneCreeps(committedLane) > 0 then
    dryTicks = 0
    rotateReason$ = "stay"
  else
    dryTicks = dryTicks + 6
    rotateReason$ = "empty_wave"
    if dryTicks >= 48 then
      bestLane = 0
      for candidateLane = 1 to 3
        if candidateLane <> committedLane and laneCreeps(candidateLane) > 0 then
          if laneHeroes(candidateLane) < laneHeroes(committedLane) then
            if bestLane = 0 then
              bestLane = candidateLane
            elseif laneHeroes(candidateLane) < laneHeroes(bestLane) then
              bestLane = candidateLane
            end if
          end if
        end if
      next candidateLane
      if bestLane <> 0 then
        committedLane = bestLane
        dryTicks = 0
        rotations = rotations + 1
        rotateReason$ = "less_crowded"
        ' One walk next to the new lane's footmen; later decisions attack.
        actMarch = actMarch + 1
        moveTo(laneFrontX(bestLane), laneFrontY(bestLane), 0)
        end
      end if
    end if
  end if
end if
' March with the committed lane's wave front; with no wave, hold at that
' lane's most forward allied building instead of any fixed map point.
actMarch = actMarch + 1
goalX = myX
goalY = myY
if laneFront(committedLane) < 1000000 then
  actWave = actWave + 1
  goalX = laneFrontX(committedLane)
  goalY = laneFrontY(committedLane)
else
  if laneAnchorRear(committedLane) >= 0 then
    goalX = frontAnchorX(committedLane)
    goalY = frontAnchorY(committedLane)
  end if
end if
if canShop() and owned(21) > 0 and selfPortalCooldown = 0 then
  dx = myX - forwardX
  dy = myY - forwardY
  if forwardDistance < 1000000 and dx * dx + dy * dy > 400 then
    if threatDistance > 144 then
      accepted = useItemAt(inventorySlot(21), originX + side * forwardX, originY + side * forwardY)
      actionError = lastActionError()
      if accepted then
        end
      end if
    end if
  end if
end if
moveTo(goalX, goalY, 1)
