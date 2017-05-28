-- Author: Shush
-- Date: 30/04/2017

CreateEmptyTalents("skeleton_king")


--------------------------------
--      WRAITHFIRE BLAST      --
--------------------------------
imba_wraith_king_wraithfire_blast = class({})
LinkLuaModifier("modifier_imba_wraithfire_blast_stun", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_wraithfire_blast_debuff", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)

function imba_wraith_king_wraithfire_blast:IsHiddenWhenStolen()
    return false
end

function imba_wraith_king_wraithfire_blast:OnSpellStart()
    -- Ability properties
    local caster = self:GetCaster()
    local ability = self
    local target = self:GetCursorTarget()
    local sound_cast = "Hero_SkeletonKing.Hellfire_Blast"
    local cast_response = {"skeleton_king_wraith_ability_hellfire_05", "skeleton_king_wraith_ability_hellfire_06", "skeleton_king_wraith_ability_hellfire_07"}
    local rare_cast_response = {"skeleton_king_wraith_ability_hellfire_03", "skeleton_king_wraith_ability_hellfire_04"}        
    local particle_warmup = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast_warmup.vpcf"    

    -- Roll for rare cast response
    if RollPercentage(5) then
        EmitSoundOn(rare_cast_response[math.random(1,#rare_cast_response)], caster)

    -- If failed, roll for normal cast response
    elseif RollPercentage(75) then
        EmitSoundOn(cast_response[math.random(1,#cast_response)], caster)
    end        

    -- Play cast sound
    EmitSoundOn(sound_cast, caster)

    -- Add warmup particle
    local particle_warmup_fx = ParticleManager:CreateParticle(particle_warmup, PATTACH_CUSTOMORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControlEnt(particle_warmup_fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_attack1", caster:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle_warmup_fx)

    -- Launch projectile
    LaunchWraithblastProjectile(caster, ability, caster, target, true)
end

function LaunchWraithblastProjectile(caster, ability, source, target, main)    
    -- Ability properties
    local particle_projectile = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast.vpcf"    

    -- Ability specials
    local projectile_speed = ability:GetSpecialValueFor("projectile_speed")

    -- Launch projectile on target    
    local wraithblast_projectile
    wraithblast_projectile = {Target = target,
                              Source = source,
                              Ability = ability,
                              EffectName = particle_projectile,
                              iMoveSpeed = projectile_speed,
                              bDodgeable = true, 
                              bVisibleToEnemies = true,
                              bReplaceExisting = false,
                              bProvidesVision = false,  
                              iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_2,
                              ExtraData = {main_blast = main}                           
    }

    ProjectileManager:CreateTrackingProjectile(wraithblast_projectile)
end

function imba_wraith_king_wraithfire_blast:OnProjectileHit_ExtraData(target, location, extra_data)
    -- If there was no target, do nothing
    if not target then
        return nil
    end

    -- Ability properties
    local caster = self:GetCaster()
    local ability = self
    local kill_response = "skeleton_king_wraith_ability_hellfire_01"
    local sound_hit = "Hero_SkeletonKing.Hellfire_BlastImpact"    
    local modifier_stun = "modifier_imba_wraithfire_blast_stun"
    local modifier_debuff = "modifier_imba_wraithfire_blast_debuff"

    -- Ability specials
    local main_target_stun_duration = ability:GetSpecialValueFor("main_target_stun_duration")
    local damage = ability:GetSpecialValueFor("damage")
    local secondary_targets_radius = ability:GetSpecialValueFor("secondary_targets_radius")
    local secondary_target_stun_duration = ability:GetSpecialValueFor("secondary_target_stun_duration")
    local debuff_duration = ability:GetSpecialValueFor("debuff_duration")
    local projectile_speed = ability:GetSpecialValueFor("projectile_speed")    

    -- #1 Talent: Wraithfire Blast debuff duration increase
    debuff_duration = debuff_duration + caster:FindTalentValue("special_bonus_imba_skeleton_king_1")

    -- Play impact sound
    EmitSoundOn(sound_hit, caster)    

    if extra_data.main_blast == 1 then
        -- If target has Linken's Sphere off cooldown, do nothing
        if target:GetTeam() ~= caster:GetTeam() then
            if target:TriggerSpellAbsorb(ability) then
                return nil
            end
        end

        -- If it was a main blast, deal damage
        local damageTable = {victim = target,
                             attacker = caster, 
                             damage = damage,
                             damage_type = DAMAGE_TYPE_MAGICAL,
                             ability = ability
                             }
        
        ApplyDamage(damageTable)

        -- Main stun the target
        target:AddNewModifier(caster, ability, modifier_stun, {duration = main_target_stun_duration})

        -- Split to enemies around
        local enemies = FindUnitsInRadius(caster:GetTeamNumber(),
                                          target:GetAbsOrigin(),
                                          nil,
                                          secondary_targets_radius,
                                          DOTA_UNIT_TARGET_TEAM_ENEMY,
                                          DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                                          DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
                                          FIND_ANY_ORDER,
                                          false)

        for _,enemy in pairs(enemies) do
            if enemy ~= target then
                LaunchWraithblastProjectile(caster, ability, target, enemy, false)
            end
        end

    else
        -- Otherwise, stun for short duration
        target:AddNewModifier(caster, ability, modifier_stun, {duration = secondary_target_stun_duration})
    end

    -- If the enemy died, play the cast response
    Timers:CreateTimer(FrameTime(), function()
        if not target:IsAlive() then
            EmitSoundOn(kill_response, caster)
        end
    end)

    -- Apply the debuff on the enemy
    target:AddNewModifier(caster, ability, modifier_debuff, {duration = debuff_duration})

    -- #7 Talent: Wraithfire Blast now summons Wraiths on all targets hit
    if caster:HasTalent("special_bonus_imba_skeleton_king_7") then
        local direction = (target:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized()
        local distance = (target:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
        local summon_point = caster:GetAbsOrigin() + direction * distance - 100
        local wraith = CreateUnitByName("npc_imba_wraith_king_wraith", summon_point, true, caster, caster, caster:GetTeamNumber())        

        -- Set the wraith as controllable by the player
        local playerid = caster:GetPlayerID()
        if playerid then
            wraith:SetControllableByPlayer(playerid, true)
        end

        -- Set the owner of the wraith as the caster
        wraith:SetOwner(caster)

        -- Set the Wraith's health to be the same as its origin
        wraith:SetBaseMaxHealth(target:GetBaseMaxHealth())
        wraith:SetMaxHealth(target:GetMaxHealth())
        wraith:SetHealth(wraith:GetMaxHealth())

        ResolveNPCPositions(target:GetAbsOrigin(), 164)
    end
end


-- Stun modifier
modifier_imba_wraithfire_blast_stun = class({})

function modifier_imba_wraithfire_blast_stun:CheckState()
    local state = {[MODIFIER_STATE_STUNNED] = true}
    return state
end

function modifier_imba_wraithfire_blast_stun:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_imba_wraithfire_blast_stun:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_imba_wraithfire_blast_stun:IsHidden() return false end
function modifier_imba_wraithfire_blast_stun:IsPurgeException() return true end
function modifier_imba_wraithfire_blast_stun:IsStunDebuff() return true end




-- Debuff modifier
modifier_imba_wraithfire_blast_debuff = class({})

function modifier_imba_wraithfire_blast_debuff:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.particle_debuff = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast_debuff.vpcf"
    self.particle_lifesteal = "particles/hero/skeleton_king/wraithblast_lifesteal.vpcf"

    -- Ability specials
    self.ms_slow_pct = self.ability:GetSpecialValueFor("ms_slow_pct")
    self.damage_per_second = self.ability:GetSpecialValueFor("damage_per_second")
    self.attacker_lifesteal_pct = self.ability:GetSpecialValueFor("attacker_lifesteal_pct")
    self.damage_interval = self.ability:GetSpecialValueFor("damage_interval")

    -- Add debuff particle    
    self.particle_debuff_fx = ParticleManager:CreateParticle(self.particle_debuff, PATTACH_ABSORIGIN_FOLLOW, self.parent)    
    ParticleManager:SetParticleControl(self.particle_debuff_fx, 0, self.parent:GetAbsOrigin())    
    self:AddParticle(self.particle_debuff_fx, false, false, -1, false, false)

    -- Start thinking
    if IsServer() then
        self:StartIntervalThink(self.damage_interval)
    end
end

function modifier_imba_wraithfire_blast_debuff:IsHidden() return false end
function modifier_imba_wraithfire_blast_debuff:IsPurgable() return true end
function modifier_imba_wraithfire_blast_debuff:IsDebuff() return true end

function modifier_imba_wraithfire_blast_debuff:OnIntervalThink()
    if IsServer() then
        -- Calculate damage
        local damage = self.damage_per_second * self.damage_interval

        local damageTable = {victim = self.parent,
                             attacker = self.caster, 
                             damage = damage,
                             damage_type = DAMAGE_TYPE_MAGICAL,
                             ability = self.ability
                             }
        
        ApplyDamage(damageTable)
    end
end

function modifier_imba_wraithfire_blast_debuff:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
                      MODIFIER_EVENT_ON_ATTACK_LANDED}

    return decFuncs
end

function modifier_imba_wraithfire_blast_debuff:GetModifierMoveSpeedBonus_Percentage()
    return self.ms_slow_pct * (-1)
end

function modifier_imba_wraithfire_blast_debuff:OnAttackLanded(keys)
    local attacker = keys.attacker
    local target = keys.target
    local damage = keys.damage

    -- Only apply if the target is the parent of the debuff
    if self.parent == target then

        -- If the attacker was on the same team, do nothing
        if attacker:GetTeamNumber() == target:GetTeamNumber() then
            return nil
        end

        -- If the attacker is a building, a ward or a courier, do nothing
        if attacker:IsBuilding() then
            return nil
        end

        -- Add lifesteal particle
        self.particle_lifesteal_fx = ParticleManager:CreateParticle(self.particle_lifesteal, PATTACH_ABSORIGIN_FOLLOW, attacker)
        ParticleManager:SetParticleControl(self.particle_lifesteal_fx, 0, attacker:GetAbsOrigin())
        ParticleManager:SetParticleControl(self.particle_lifesteal_fx, 1, attacker:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(self.particle_lifesteal_fx)

        -- If it's an illusion, it doesn't heal (just fakes it)
        if attacker:IsIllusion() then
            return nil
        end

        -- Calculate heal amount based on damage
        local heal_amount = damage * self.attacker_lifesteal_pct * 0.01

        -- Heal the attacker
        attacker:Heal(heal_amount, self.caster)
    end
end




--------------------------------
--      VAMPIRIC AURA      --
--------------------------------
imba_wraith_king_vampiric_aura = class({})
LinkLuaModifier("modifier_imba_vampiric_aura", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_vampiric_aura_buff", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)

function imba_wraith_king_vampiric_aura:OnToggle() return nil end
function imba_wraith_king_vampiric_aura:IsStealable() return false end

function imba_wraith_king_vampiric_aura:GetIntrinsicModifierName()
    return "modifier_imba_vampiric_aura"
end

-- Aura modifier
modifier_imba_vampiric_aura = class({})

function modifier_imba_vampiric_aura:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()

    -- Ability specials
    self.radius = self.ability:GetSpecialValueFor("radius")
end

function modifier_imba_vampiric_aura:AllowIllusionDuplicate() return true end
function modifier_imba_vampiric_aura:IsHidden() return true end
function modifier_imba_vampiric_aura:IsPurgable() return false end
function modifier_imba_vampiric_aura:IsDebuff() return false end    

function modifier_imba_vampiric_aura:GetAuraRadius()
    return self.radius
end

function modifier_imba_vampiric_aura:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

function modifier_imba_vampiric_aura:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_imba_vampiric_aura:GetAuraSearchType()
    local toggle = self.ability:GetToggleState()

    if toggle then
        return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
    else
        return DOTA_UNIT_TARGET_HERO
    end
end

function modifier_imba_vampiric_aura:GetModifierAura()
    return "modifier_imba_vampiric_aura_buff"
end

function modifier_imba_vampiric_aura:IsAura()
    -- If caster is broken, no aura is emitted
    if self.caster:PassivesDisabled() then
        return false
    end

    return true
end


-- Aura buff modifier
modifier_imba_vampiric_aura_buff = class({})

function modifier_imba_vampiric_aura_buff:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.particle_lifesteal = "particles/units/heroes/hero_skeletonking/wraith_king_vampiric_aura_lifesteal.vpcf"
    self.particle_spellsteal = "particles/hero/skeleton_king/skeleton_king_vampiric_aura_lifesteal.vpcf"

    -- Ability specials
    self.radius = self.ability:GetSpecialValueFor("radius")
    self.lifesteal_pct = self.ability:GetSpecialValueFor("lifesteal_pct")
    self.spellsteal_pct = self.ability:GetSpecialValueFor("spellsteal_pct")
    self.caster_heal = self.ability:GetSpecialValueFor("caster_heal")
    self.heal_delay = self.ability:GetSpecialValueFor("heal_delay")    
end

function modifier_imba_vampiric_aura_buff:OnRefresh()
    self:OnCreated()
end

function modifier_imba_vampiric_aura_buff:IsHidden() return false end
function modifier_imba_vampiric_aura_buff:IsPurgable() return false end
function modifier_imba_vampiric_aura_buff:IsDebuff() return false end

function modifier_imba_vampiric_aura_buff:DeclareFunctions()
    local decFuncs = {MODIFIER_EVENT_ON_TAKEDAMAGE}

    return decFuncs
end

function modifier_imba_vampiric_aura_buff:OnTakeDamage(keys)
    if IsServer() then
        local attacker = keys.attacker
        local damage = keys.damage
        local damage_type = keys.damage_type
        local target = keys.unit

        -- Only apply on the parent attacks
        if self.parent == attacker then

            local heal_amount = 0

            -- If the target is on the same team, do nothing
            if attacker:GetTeamNumber() == target:GetTeamNumber() then
                return nil
            end

            -- If the target is a building, a courier or a ward, do nothing
            if target:IsBuilding() or target:IsOther() then
                return nil
            end

            -- If the damage was physical, use the lifesteal particle, and heal using the lifesteal values
            if damage_type == DAMAGE_TYPE_PHYSICAL then
                local particle_lifesteal_fx = ParticleManager:CreateParticle(self.particle_lifesteal, PATTACH_CUSTOMORIGIN_FOLLOW, attacker)
                ParticleManager:SetParticleControlEnt(particle_lifesteal_fx, 0, attacker, PATTACH_POINT_FOLLOW, "attach_hitloc", attacker:GetAbsOrigin(), true)                
                ParticleManager:SetParticleControlEnt(particle_lifesteal_fx, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)                                
                ParticleManager:ReleaseParticleIndex(particle_lifesteal_fx)                

                -- If it was an illusion, no heal is done (fakes lifesteal)
                if attacker:IsIllusion() then
                    return nil
                end

                -- #3 Talent: Vampiric Aura lifesteal/spellsteal increase
                local lifesteal_pct = self.lifesteal_pct + self.caster:FindTalentValue("special_bonus_imba_skeleton_king_3")

                -- Calculate lifesteal and heal the attacker
                heal_amount = damage * lifesteal_pct * 0.01
                self.parent:Heal(heal_amount, self.caster)

            -- If the damage was magical or pure, use the skeletonking particle instead, and heal using the spellsteal values
            else
                local particle_spellsteal_fx = ParticleManager:CreateParticle(self.particle_spellsteal, PATTACH_CUSTOMORIGIN_FOLLOW, attacker)
                ParticleManager:SetParticleControlEnt(particle_spellsteal_fx, 0, attacker, PATTACH_POINT_FOLLOW, "attach_hitloc", attacker:GetAbsOrigin(), true)                
                ParticleManager:SetParticleControlEnt(particle_spellsteal_fx, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)                
                ParticleManager:ReleaseParticleIndex(particle_spellsteal_fx)

                -- If it was an illusion, no heal is done (fakes lifesteal)
                if attacker:IsIllusion() then
                    return nil
                end

                -- #3 Talent: Vampiric Aura lifesteal/spellsteal increase
                local spellsteal_pct = self.spellsteal_pct + self.caster:FindTalentValue("special_bonus_imba_skeleton_king_3")

                -- Calculate lifesteal and heal the attacker
                heal_amount = damage * spellsteal_pct * 0.01
                self.parent:Heal(heal_amount, self.caster)
            end

            -- After a small delay, find both illusions and the real aura bearer
            Timers:CreateTimer(self.heal_delay, function()
                local casters = FindUnitsInRadius(self.parent:GetTeamNumber(),
                                                  self.parent:GetAbsOrigin(),
                                                  nil,
                                                  self.radius,
                                                  DOTA_UNIT_TARGET_TEAM_FRIENDLY,
                                                  DOTA_UNIT_TARGET_HERO,
                                                  DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
                                                  FIND_ANY_ORDER,
                                                  false)

                for _,caster in pairs(casters) do

                    -- Ignore everyone that are not the same name as the caster
                    if caster:GetUnitName() == self.caster:GetUnitName() and attacker:GetUnitName() ~= self.caster:GetUnitName() then

                        -- If any healing was done by anyone that is not the caster, show a transition to the aura bearer(s)            
                        if heal_amount > 0 and caster ~= attacker then
                            local particle_lifesteal_fx = ParticleManager:CreateParticle(self.particle_lifesteal, PATTACH_CUSTOMORIGIN_FOLLOW, caster)
                            ParticleManager:SetParticleControlEnt(particle_lifesteal_fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)                
                            ParticleManager:SetParticleControlEnt(particle_lifesteal_fx, 1, self.parent, PATTACH_POINT_FOLLOW, "attach_hitloc", self.parent:GetAbsOrigin(), true)                                
                            ParticleManager:ReleaseParticleIndex(particle_lifesteal_fx)                                        

                            -- Heal the aura bearer, if it's a real hero
                            if caster:IsRealHero() then
                                local caster_heal = heal_amount * self.caster_heal * 0.01
                                caster:Heal(caster_heal, caster)
                            end
                        end
                    end
                end
            end)
        end
    end
end




--------------------------------
--       MORTAL STRIKE        --
--------------------------------
imba_wraith_king_mortal_strike = class({})
LinkLuaModifier("modifier_imba_mortal_strike", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_mortal_strike_buff", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)

function imba_wraith_king_mortal_strike:GetIntrinsicModifierName()
    return "modifier_imba_mortal_strike"
end


-- Critical strikes modifier
modifier_imba_mortal_strike = class({})

function modifier_imba_mortal_strike:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.modifier_health = "modifier_imba_mortal_strike_buff"

    -- Ability specials
    self.crit_chance = self.ability:GetSpecialValueFor("crit_chance")
    self.crit_damage_heroes = self.ability:GetSpecialValueFor("crit_damage_heroes")
    self.crit_damage_creeps = self.ability:GetSpecialValueFor("crit_damage_creeps")
    self.bonus_health_pct = self.ability:GetSpecialValueFor("bonus_health_pct")
    self.bonus_health_duration = self.ability:GetSpecialValueFor("bonus_health_duration")
    self.bonus_health_hero_mult = self.ability:GetSpecialValueFor("bonus_health_hero_mult")
    self.stack_value = self.ability:GetSpecialValueFor("stack_value")
end

function modifier_imba_mortal_strike:OnRefresh()
    self:OnCreated()
end

function modifier_imba_mortal_strike:IsHidden() return true end
function modifier_imba_mortal_strike:IsPurgable() return false end
function modifier_imba_mortal_strike:IsDebuff() return false end

function modifier_imba_mortal_strike:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
                      MODIFIER_EVENT_ON_ATTACK_LANDED}

    return decFuncs
end

function modifier_imba_mortal_strike:GetModifierPreAttack_CriticalStrike(keys)
    if IsServer() then
        local attacker = keys.attacker
        local target = keys.target

        -- Only apply on attacks of the caster
        if attacker == self.caster then

            -- If the caster is broken, do nothing
            if self.caster:PassivesDisabled() then
                return nil
            end

            -- If the target is on the friendly team, do nothing
            if target:GetTeamNumber() == self.caster:GetTeamNumber() then
                return nil
            end

            -- #2 Talent: Mortal Strike chance increase
            local crit_chance = self.crit_chance + self.caster:FindTalentValue("special_bonus_imba_skeleton_king_2")

            -- Psuedo Roll for a critical            
            if RollPseudoRandom(crit_chance, self) then

                -- Mark this attack as a critical for a small duration
                self.mortal_critical_strike = true

                Timers:CreateTimer(self.caster:GetAttackSpeed(), function()                    
                    self.mortal_critical_strike = false
                end)    

                -- Determine crit power, depending on the target type
                if target:IsHero() then
                    return self.crit_damage_heroes
                else
                    return self.crit_damage_creeps
                end
            end
        end
    end
end

function modifier_imba_mortal_strike:OnAttackLanded(keys)
    if IsServer() then
        local attacker = keys.attacker
        local target = keys.target
        local damage = keys.damage

        -- Only apply on attacks of the caster
        if attacker == self.caster then            

            -- If this attack was not a crit, do nothing
            if not self.mortal_critical_strike then
                return nil
            end

            -- Remove crit mark
            self.mortal_critical_strike = false            

            -- #5 Talent: Mortal Strike bonus health per damage
            local bonus_health_pct = self.bonus_health_pct + self.caster:FindTalentValue("special_bonus_imba_skeleton_king_5")

            -- Calculate stacks to add
            local new_stacks = damage * bonus_health_pct * 0.01

            -- If the target was a real hero, increase the bonus health gained from critting it
            if target:IsRealHero() then
                new_stacks = new_stacks * self.bonus_health_hero_mult
            end

            -- Each stack has its value, so the actual number of stacks is lower. Number is always rounded up 
            new_stacks = math.ceil(new_stacks / self.stack_value)

            -- Add (or refresh) the bonus health modifier
            local modifier_health_handler = self.caster:AddNewModifier(self.caster, self.ability, self.modifier_health, {duration = self.bonus_health_duration})
            if modifier_health_handler then
                for i = 1, new_stacks do
                    modifier_health_handler:IncrementStackCount()
                    modifier_health_handler:ForceRefresh()
                end                
            end
        end
    end
end


-- Bonus health modifier
modifier_imba_mortal_strike_buff = class({})

function modifier_imba_mortal_strike_buff:OnCreated()
    if IsServer() then
        -- Ability properties
        self.caster = self:GetCaster()
        self.ability = self:GetAbility()

        -- Ability specials
        self.bonus_health_duration = self.ability:GetSpecialValueFor("bonus_health_duration")
        self.stack_value = self.ability:GetSpecialValueFor("stack_value")

        -- Initialize table
        self.stacks_table = {}        

        -- Start thinking
        self:StartIntervalThink(0.1)
    end
end

function modifier_imba_mortal_strike_buff:IsHidden() return false end
function modifier_imba_mortal_strike_buff:IsPurgable() return false end
function modifier_imba_mortal_strike_buff:IsDebuff() return false end

function modifier_imba_mortal_strike_buff:OnIntervalThink()
    if IsServer() then

        -- Check if there are any stacks left on the table
        if #self.stacks_table > 0 then

            -- For each stack, check if it is past its expiration time. If it is, remove it from the table
            for i = #self.stacks_table, 1, -1 do
                if self.stacks_table[i] + self.bonus_health_duration < GameRules:GetGameTime() then
                    table.remove(self.stacks_table, i)             
                end
            end
            
            -- If after removing the stacks, the table is empty, remove the modifier.
            if #self.stacks_table == 0 then
                self:Destroy()

            -- Otherwise, set its stack count
            else
                self:SetStackCount(#self.stacks_table)
            end

            -- Recalculate health bonus based on new stack count
            self:GetParent():CalculateStatBonus()

        -- If there are no stacks on the table, just remove the modifier.
        else
            self:Destroy()
        end
    end
end

function modifier_imba_mortal_strike_buff:OnRefresh()
    if IsServer() then
        -- Insert new stack values
        table.insert(self.stacks_table, GameRules:GetGameTime())
    end
end

function modifier_imba_mortal_strike_buff:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_HEALTH_BONUS,
                      MODIFIER_PROPERTY_STATS_STRENGTH_BONUS}

    return decFuncs
end

function modifier_imba_mortal_strike_buff:GetModifierHealthBonus()
    if self.caster:IsIllusion() then
        return nil
    end

    local stacks = self:GetStackCount()
    return stacks * self.stack_value
end

function modifier_imba_mortal_strike_buff:GetModifierBonusStats_Strength()
    if self.caster:IsIllusion() then
        return nil
    end

    -- #8 Talent: Mortal Strikes grants strength
    if self.caster:HasTalent("special_bonus_imba_skeleton_king_8") then
        local stacks = self:GetStackCount()
        return stacks
    end
end




--------------------------------
--       REINCARNATION        --
--------------------------------
imba_wraith_king_reincarnation = imba_wraith_king_reincarnation or class({})
LinkLuaModifier("modifier_imba_reincarnation", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_reincarnation_wraith_form_buff", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_reincarnation_wraith_form", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)

function imba_wraith_king_reincarnation:GetManaCost(level)
    local caster = self:GetCaster()
    local ability = self    
    local reincarnate_mana_cost = ability:GetSpecialValueFor("reincarnate_mana_cost")

    -- #6 Talent: Reincarnation no longer needs mana
    reincarnate_mana_cost = reincarnate_mana_cost - caster:FindTalentValue("special_bonus_imba_skeleton_king_6")

    return reincarnate_mana_cost
end

function imba_wraith_king_reincarnation:GetIntrinsicModifierName()
    return "modifier_imba_reincarnation"
end

-- Reicarnation modifier
modifier_imba_reincarnation = modifier_imba_reincarnation or class({})

function modifier_imba_reincarnation:OnCreated()    
        -- Ability properties
        self.caster = self:GetCaster()
        self.ability = self:GetAbility()    
        self.particle_death = "particles/units/heroes/hero_skeletonking/wraith_king_reincarnate.vpcf"
        self.sound_death = "Hero_SkeletonKing.Reincarnate"
        self.sound_reincarnation = "Hero_SkeletonKing.Reincarnate.Stinger"
        self.sound_be_back = "Hero_WraithKing.IllBeBack"
        self.modifier_wraith = "modifier_imba_reincarnation_wraith_form"

        -- Ability specials
        self.reincarnate_delay = self.ability:GetSpecialValueFor("reincarnate_delay")
        self.passive_respawn_haste = self.ability:GetSpecialValueFor("passive_respawn_haste")        
        self.slow_radius = self.ability:GetSpecialValueFor("slow_radius")
        self.slow_duration = self.ability:GetSpecialValueFor("slow_duration")
        self.scepter_wraith_form_radius = self.ability:GetSpecialValueFor("scepter_wraith_form_radius")        

    if IsServer() then
        -- Set WK as immortal!
        self.can_die = false

        -- Start interval think
        self:StartIntervalThink(FrameTime())
    end
end

function modifier_imba_reincarnation:IsHidden() return true end
function modifier_imba_reincarnation:IsPurgable() return false end
function modifier_imba_reincarnation:IsDebuff() return false end

function modifier_imba_reincarnation:OnIntervalThink()
    -- If caster has sufficent mana and the ability is ready, apply
    if (self.caster:GetMana() >= self.ability:GetManaCost(-1)) and (self.ability:IsCooldownReady()) and (not self.caster:HasModifier("modifier_item_imba_aegis")) then
        self.can_die = false
    else
        self.can_die = true
    end
end

function modifier_imba_reincarnation:OnRefresh()
    self:OnCreated()
end

function modifier_imba_reincarnation:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_REINCARNATION,                      
                      MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
                      MODIFIER_EVENT_ON_DEATH,
                      MODIFIER_PROPERTY_RESPAWNTIME_STACKING}

    return decFuncs
end

function modifier_imba_reincarnation:ReincarnateTime()
    if IsServer() then  
        if not self.can_die and self.caster:IsRealHero() then
            return self.reincarnate_delay
        end

        return nil
    end
end

function modifier_imba_reincarnation:RespawnTimeStacking()
    return self.passive_respawn_haste * (-1)
end

function modifier_imba_reincarnation:GetActivityTranslationModifiers()
    if self.reincarnation_death then
        return "reincarnate"
    end

    return nil
end

function modifier_imba_reincarnation:OnDeath(keys)
    if IsServer() then
        local unit = keys.unit
        local reincarnate = keys.reincarnate

        -- Only apply if the caster is the unit that died
        if self.caster == unit then            

            -- Check if it was a reincarnation death
            if reincarnate and (not self.caster:HasModifier("modifier_item_imba_aegis")) then
				self.reincarnation_death = true

                -- Use the Reincarnation's ability cooldown
                self.ability:UseResources(false, false, true)

                -- Play reincarnate sound
                local heroes = FindUnitsInRadius(self.caster:GetTeamNumber(),
                                                 self.caster:GetAbsOrigin(),
                                                 nil,
                                                 self.slow_radius,
                                                 DOTA_UNIT_TARGET_TEAM_ENEMY,
                                                 DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                                                 DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
                                                 FIND_ANY_ORDER,
                                                 false)

                if USE_MEME_SOUNDS and #heroes >= IMBA_PLAYERS_ON_GAME * 0.35 then
                    self.caster:EmitSound(self.sound_be_back)
                else
                    self.caster:EmitSound(self.sound_death)
                end    

                -- Add particle effects
                local particle_death_fx = ParticleManager:CreateParticle(self.particle_death, PATTACH_CUSTOMORIGIN, self.caster)
                ParticleManager:SetParticleAlwaysSimulate(particle_death_fx)
                ParticleManager:SetParticleControl(particle_death_fx, 0, self.caster:GetAbsOrigin())
                ParticleManager:SetParticleControl(particle_death_fx, 1, Vector(self.reincarnate_delay, 0, 0))
                ParticleManager:SetParticleControl(particle_death_fx, 11, Vector(200, 0, 0))
                ParticleManager:ReleaseParticleIndex(particle_death_fx)

                -- Add a FOW Viewer, depending on if it is a day or night
                if IsDaytime() then
                    AddFOWViewer(self.caster:GetTeamNumber(), self.caster:GetAbsOrigin(), self.caster:GetDayTimeVisionRange(), self.reincarnate_delay, true)
                else
                    AddFOWViewer(self.caster:GetTeamNumber(), self.caster:GetAbsOrigin(), self.caster:GetNightTimeVisionRange(), self.reincarnate_delay, true)
                end

                -- Wait for the caster to reincarnate, then play its sound
                Timers:CreateTimer(self.reincarnate_delay, function()
                    EmitSoundOn(self.sound_reincarnation, self.caster) 
                end)                
        
            else                
                self.reincarnation_death = false     
            end
        end
    end
end

-- WRAITH FORM AURA FUNCTIONS
function modifier_imba_reincarnation:GetAuraRadius()
    return self.scepter_wraith_form_radius
end

function modifier_imba_reincarnation:GetAuraEntityReject(target)
    -- Aura ignores everyone that are already under the effects of Wraith Form 
    if target:HasModifier(self.modifier_wraith) then
        return true 
    end

    return false    
end

function modifier_imba_reincarnation:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS + DOTA_UNIT_TARGET_FLAG_NOT_CREEP_HERO
end

function modifier_imba_reincarnation:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_imba_reincarnation:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO
end

function modifier_imba_reincarnation:GetModifierAura()
    return "modifier_imba_reincarnation_wraith_form_buff"
end

function modifier_imba_reincarnation:IsAura()
    if self.caster:HasScepter() then
        return true        
    end

    return false
end

function modifier_imba_reincarnation:IsAuraActiveOnDeath()
    return true
end


-- Wraith Form modifier (given from aura, not yet Wraith Form)
modifier_imba_reincarnation_wraith_form_buff = modifier_imba_reincarnation_wraith_form_buff or class({})

function modifier_imba_reincarnation_wraith_form_buff:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.modifier_wraith_form = "modifier_imba_reincarnation_wraith_form"

    -- Ability specials    
    self.scepter_wraith_form_duration = self.ability:GetSpecialValueFor("scepter_wraith_form_duration")
    self.max_wraith_form_heroes = self.ability:GetSpecialValueFor("max_wraith_form_heroes")
end

function modifier_imba_reincarnation_wraith_form_buff:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_MIN_HEALTH,
                      MODIFIER_EVENT_ON_TAKEDAMAGE}

    return decFuncs
end

function modifier_imba_reincarnation_wraith_form_buff:GetMinHealth()
    return 1
end

function modifier_imba_reincarnation_wraith_form_buff:OnTakeDamage(keys)
    if IsServer() then
        local attacker = keys.attacker
        local target = keys.unit 
        local damage = keys.damage

        -- Only apply if the unit taking damage is the parent
        if self.parent == target then
            
            -- Check if the damage is fatal 
            if damage >= self.parent:GetHealth() then

                -- Check for Shallow Grave: nothing happens
                if self.parent:HasModifier("modifier_imba_dazzle_shallow_grave") or self.parent:HasModifier("modifier_imba_dazzle_nothl_protection") then
                    return nil
                end

                -- Check for Aegis: kill the unit normally
                if self.parent:HasModifier("modifier_item_imba_aegis") then
                    self:Destroy()
                    self.parent:Kill(self.ability, attacker)
                    return nil
                end

                -- Check if this unit has Reincarnation and it is ready: if so, kill the unit normally
                if self.parent:HasAbility(self.ability:GetAbilityName()) then
                    local reincarnation_ability = self.parent:FindAbilityByName(self.ability:GetAbilityName())
                    if reincarnation_ability then
                        if self.parent:GetMana() >= reincarnation_ability:GetManaCost(-1) and reincarnation_ability:IsCooldownReady() then
                            self:Destroy()
                            self.parent:Kill(self.ability, attacker)
                            return nil
                        end
                    end
                end

                -- Search heroes that are already in Wraith Form, except for the caster
                local allied_heroes = FindUnitsInRadius(self.caster:GetTeamNumber(),
                                                        self.caster:GetAbsOrigin(),
                                                        nil,
                                                        25000, -- global
                                                        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
                                                        DOTA_UNIT_TARGET_HERO,
                                                        DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,
                                                        FIND_ANY_ORDER,
                                                        false)

                local heroes_in_wraith_form = 0
                for _,allied_hero in pairs(allied_heroes) do
                    if allied_hero ~= self.caster and allied_hero:HasModifier(self.modifier_wraith_form) then
                        heroes_in_wraith_form = heroes_in_wraith_form + 1
                    end
                end

                -- If the amount of units with Wraith Form are above the limit, just kill the unit normally
                if heroes_in_wraith_form >= self.max_wraith_form_heroes and self.caster ~= self.parent then
                    self:Destroy()
                    self.parent:Kill(self.ability, attacker)
                end

                -- Assign the killer to the modifier, which would actually kill the hero later
                local wraith_form_modifier_handler = self.parent:AddNewModifier(self.caster, self.ability, self.modifier_wraith_form, {duration = self.scepter_wraith_form_duration})
                if wraith_form_modifier_handler then
                    wraith_form_modifier_handler.original_killer = attacker
					wraith_form_modifier_handler.ability_killer = keys.inflictor
					if keys.inflictor then
						if keys.inflictor:GetName() == "imba_necrolyte_reapers_scythe" then
							keys.inflictor.ghost_death = true
						end
					end
                end                
            end
        end
    end
end


-- Wraith Form (actual Wraith Form)
modifier_imba_reincarnation_wraith_form = modifier_imba_reincarnation_wraith_form or class({})

function modifier_imba_reincarnation_wraith_form:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
end

function modifier_imba_reincarnation_wraith_form:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
                      MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
                      MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
                      MODIFIER_PROPERTY_DISABLE_HEALING,
                      MODIFIER_PROPERTY_MODEL_SCALE}

    return decFuncs
end

function modifier_imba_reincarnation_wraith_form:GetAbsoluteNoDamageMagical()
    return 1
end

function modifier_imba_reincarnation_wraith_form:GetAbsoluteNoDamagePhysical()
    return 1
end

function modifier_imba_reincarnation_wraith_form:GetAbsoluteNoDamagePure()
    return 1
end

function modifier_imba_reincarnation_wraith_form:GetDisableHealing()
    return 1
end

function modifier_imba_reincarnation_wraith_form:GetModifierModelScale()
    return 105
end

function modifier_imba_reincarnation_wraith_form:CheckState()
    local state = {[MODIFIER_STATE_NO_HEALTH_BAR] = true,
                   [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
                   [MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true}
    return state
end

function modifier_imba_reincarnation_wraith_form:OnDestroy()
    if IsServer() then
        -- Force kill the unit
        TrueKill(self.original_killer, self.parent, self.ability_killer)
    end
end

function modifier_imba_reincarnation_wraith_form:GetStatusEffectName()
    return "particles/status_fx/status_effect_wraithking_ghosts.vpcf"
end





--------------------------------
--        KINGDOM COME        --
--------------------------------
imba_wraith_king_kingdom_come = imba_wraith_king_kingdom_come or class({})
LinkLuaModifier("modifier_imba_kingdom_come", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)    
LinkLuaModifier("modifier_imba_kingdom_come_slow", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_kingdom_come_stun", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)

function imba_wraith_king_kingdom_come:IsNetherWardStealable() return false end
function imba_wraith_king_kingdom_come:IsInnateAbility()
    return true
end

function imba_wraith_king_kingdom_come:GetIntrinsicModifierName()
    return "modifier_imba_kingdom_come"
end


modifier_imba_kingdom_come = class({})

function modifier_imba_kingdom_come:OnCreated()
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.sound_kingdom = "Hero_WraithKing.EruptionCast"
    self.particle_kingdom = "particles/hero/skeleton_king/wraith_king_hellfire_eruption_tell.vpcf"
    self.modifier_slow = "modifier_imba_kingdom_come_slow"

    -- Ability specials
    self.radius = self.ability:GetSpecialValueFor("radius")
    self.slow_duration = self.ability:GetSpecialValueFor("slow_duration")        
end

function modifier_imba_kingdom_come:IsHidden() return true end
function modifier_imba_kingdom_come:IsPurgable() return false end
function modifier_imba_kingdom_come:IsDebuff() return false end

function modifier_imba_kingdom_come:DeclareFunctions()
    local decFuncs = {MODIFIER_EVENT_ON_DEATH}

    return decFuncs
end

function modifier_imba_kingdom_come:OnDeath(keys)
    if IsServer() then
        local unit = keys.unit

        -- Only apply on the caster dying
        if self.caster == unit then

            -- If the caster is an illusion, do nothing
            if self.caster:IsIllusion() then
                return nil
            end

            -- Apply the slow on all nearby units
            local enemy_units = FindUnitsInRadius(self.caster:GetTeamNumber(),
                                             self.caster:GetAbsOrigin(),
                                             nil,
                                             self.radius,
                                             DOTA_UNIT_TARGET_TEAM_ENEMY,
                                             DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                                             DOTA_UNIT_TARGET_FLAG_NONE,
                                             FIND_ANY_ORDER,
                                             false)

            for _,enemy_unit in pairs(enemy_units) do
                enemy_unit:AddNewModifier(self.caster, self.ability, self.modifier_slow, {duration = self.slow_duration})
            end

            -- Play the Wraith Fire ring particle
            local particle_kingdom_fx = ParticleManager:CreateParticle(self.particle_kingdom, PATTACH_ABSORIGIN, self.caster)
            ParticleManager:SetParticleControl(particle_kingdom_fx, 0, self.caster:GetAbsOrigin())
            ParticleManager:SetParticleControl(particle_kingdom_fx, 1, Vector(self.radius, 1, 1))

            -- Add a FOW Viewer
            AddFOWViewer(self.caster:GetTeamNumber(), self.caster:GetAbsOrigin(), self.radius, self.slow_duration, false)

            Timers:CreateTimer(self.slow_duration, function()
                ParticleManager:DestroyParticle(particle_kingdom_fx, false)
                ParticleManager:ReleaseParticleIndex(particle_kingdom_fx)
            end)
        end
    end
end

-- Kingdom Come slow
modifier_imba_kingdom_come_slow = class({})

function modifier_imba_kingdom_come_slow:OnCreated()    
    -- Ability properties
    self.caster = self:GetCaster()
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.particle_slow = "particles/units/heroes/hero_skeletonking/wraith_king_reincarnate_slow_debuff.vpcf"
    self.modifier_stun = "modifier_imba_kingdom_come_stun"

    -- Ability specials
    self.ms_slow_pct = self.ability:GetSpecialValueFor("ms_slow_pct")
    self.as_slow = self.ability:GetSpecialValueFor("as_slow")
    self.stun_duration = self.ability:GetSpecialValueFor("stun_duration")
    self.damage = self.ability:GetSpecialValueFor("damage")    

    -- Add particle effect
    local particle_slow_fx = ParticleManager:CreateParticle(self.particle_slow, PATTACH_ABSORIGIN_FOLLOW, self.parent)
    ParticleManager:SetParticleControl(particle_slow_fx, 0, self.parent:GetAbsOrigin())
    self:AddParticle(particle_slow_fx, false, false, -1, false, false)    
end

function modifier_imba_kingdom_come_slow:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
                      MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT}

    return decFuncs
end

function modifier_imba_kingdom_come_slow:IsHidden() return false end
function modifier_imba_kingdom_come_slow:IsPurgable() return true end
function modifier_imba_kingdom_come_slow:IsDebuff() return true end

function modifier_imba_kingdom_come_slow:GetModifierMoveSpeedBonus_Percentage()
    return self.ms_slow_pct * (-1)
end

function modifier_imba_kingdom_come_slow:GetModifierAttackSpeedBonus_Constant()
    return self.as_slow * (-1)
end

function modifier_imba_kingdom_come_slow:OnDestroy()    
    if IsServer() then
        -- If this is a real hero, stun and deal damage to it
        if self.parent:IsRealHero() then
            self.parent:AddNewModifier(self.caster, self.ability, self.modifier_stun, {duration = self.stun_duration})

            local damageTable = {victim = self.parent,
                                 attacker = self.caster, 
                                 damage = self.damage,
                                 damage_type = DAMAGE_TYPE_MAGICAL,
                                 ability = self.ability
                                 }
            
            ApplyDamage(damageTable)

            -- Summon a Wraith near it
            local direction = (self.parent:GetAbsOrigin() - self.caster:GetAbsOrigin()):Normalized()
            local distance = (self.parent:GetAbsOrigin() - self.caster:GetAbsOrigin()):Length2D()
            local summon_point = self.caster:GetAbsOrigin() + direction * distance - 100
            local wraith = CreateUnitByName("npc_imba_wraith_king_wraith", summon_point, true, self.caster, self.caster, self.caster:GetTeamNumber())        

            -- Set the wraith as controllable by the player
            local playerid = self.caster:GetPlayerID()
            if playerid then
                wraith:SetControllableByPlayer(playerid, true)
            end

            -- Set the owner of the wraith as the caster
            wraith:SetOwner(self.caster)

            -- Set the Wraith's health to be the same as its origin
            wraith:SetBaseMaxHealth(self.parent:GetBaseMaxHealth())
            wraith:SetMaxHealth(self.parent:GetMaxHealth())
            wraith:SetHealth(wraith:GetMaxHealth())

            ResolveNPCPositions(self.parent:GetAbsOrigin(), 164)

        -- If it is a creep or an illusion, instantly kill it
        else          
            if not IsRoshan(self.parent) then  
                self.parent:Kill(self.ability, self.caster)
            end
        end
    end
end


-- Kingdom Come stun modifier
modifier_imba_kingdom_come_stun = class({})

function modifier_imba_kingdom_come_stun:CheckState()
    local state = {[MODIFIER_STATE_STUNNED] = true}
    return state
end

function modifier_imba_kingdom_come_stun:IsHidden() return false end
function modifier_imba_kingdom_come_stun:IsPurgeException() return false end 
function modifier_imba_kingdom_come_stun:IsStunDebuff() return false end

function modifier_imba_kingdom_come_stun:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_imba_kingdom_come_stun:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end




--------------------------------
--    WRAITH'S SOUL STRIKE    --
--------------------------------
imba_wraith_king_wraith_soul_strike = class({})
LinkLuaModifier("modifier_imba_wraith_soul_strike", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)    
LinkLuaModifier("modifier_imba_wraith_soul_strike_slow", "hero/hero_skeleton_king.lua", LUA_MODIFIER_MOTION_NONE)    

function imba_wraith_king_wraith_soul_strike:GetIntrinsicModifierName()
    return "modifier_imba_wraith_soul_strike"
end


modifier_imba_wraith_soul_strike = class({})

function modifier_imba_wraith_soul_strike:OnCreated()
    if IsServer() then
        -- Ability properties
        self.caster = self:GetCaster()    
        self.ability = self:GetAbility()
        self.owner = self.caster:GetOwner()
        self.modifier_slow = "modifier_imba_wraith_soul_strike_slow"

        -- Ability specials
        self.wraiths_attacks = self.ability:GetSpecialValueFor("wraiths_attacks")
        self.max_hp_as_damage_pct = self.ability:GetSpecialValueFor("max_hp_as_damage_pct")

        -- Set starting stack count
        self:SetStackCount(self.wraiths_attacks)
    end
end

function modifier_imba_wraith_soul_strike:DeclareFunctions()
    local decFuncs = {MODIFIER_EVENT_ON_ATTACK,
                      MODIFIER_EVENT_ON_ATTACK_LANDED}

    return decFuncs
end

function modifier_imba_wraith_soul_strike:OnAttack(keys)
    if IsServer() then
        local target = keys.target
        local attacker = keys.attacker

        -- Only apply on caster's attacks 
        if attacker == self.caster then

            -- Reduce a stack
            self:DecrementStackCount()     

            -- If there are no more stacks, kill the Wraith            
            local stacks = self:GetStackCount()
            if stacks == 0 then            
                Timers:CreateTimer(0.3, function()
                    self.caster:Kill(self.ability, self.caster)
                end)
            end
        end
    end
end 

function modifier_imba_wraith_soul_strike:OnAttackLanded(keys)    
    local target = keys.target
    local attacker = keys.attacker

    -- Only apply on caster's attacks 
    if attacker == self.caster then

        -- If the target is a building, do nothing
        if target:IsBuilding() then
            return nil
        end

        -- Calculate damage based on Max HP
        local damage = self.caster:GetMaxHealth() * self.max_hp_as_damage_pct * 0.01

        -- Deal pure damage to enemy 
        local damageTable = {victim = target,
                             attacker = self.caster, 
                             damage = damage,
                             damage_type = DAMAGE_TYPE_PURE,
                             ability = self.ability
                             }
        
        ApplyDamage(damageTable)

        -- #4 Talent: Kingdom Come Wraiths's attacks slow enemies
        if self.owner:HasTalent("special_bonus_imba_skeleton_king_4") then
            local duration = self.owner:FindSpecificTalentValue("special_bonus_imba_skeleton_king_4", "duration")

            target:AddNewModifier(self.caster, self.ability, self.modifier_slow, {duration = duration})
        end
    end
end


-- Soul Strike slow modifier - #4 Talent
modifier_imba_wraith_soul_strike_slow = class({})

function modifier_imba_wraith_soul_strike_slow:OnCreated()
    if IsServer() then
        -- Ability properties
        self.caster = self:GetCaster()
        self.ability = self:GetAbility()
        self.owner = self.caster:GetOwner()

        -- Talent properties
        self.ms_slow_pct = self.owner:FindSpecificTalentValue("special_bonus_imba_skeleton_king_4", "ms_slow_pct")

        -- Set server count
        self:SetStackCount(self.ms_slow_pct)

        self.ability:SetRefCountsModifiers(true)
    end
end

function modifier_imba_wraith_soul_strike_slow:IsHidden() return false end
function modifier_imba_wraith_soul_strike_slow:IsPurgable() return false end
function modifier_imba_wraith_soul_strike_slow:IsDebuff() return false end

function modifier_imba_wraith_soul_strike_slow:DeclareFunctions()
    local decFuncs = {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE}

    return decFuncs
end

function modifier_imba_wraith_soul_strike_slow:GetModifierMoveSpeedBonus_Percentage()
    return self:GetStackCount() * (-1)
end