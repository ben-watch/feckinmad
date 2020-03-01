
StartSpeedrunning(id)
{
	set_pev(id, pev_health, 50.0)
	set_pev(id, pev_gravity, 1.0)
	set_pev(id, pev_movetype, MOVETYPE_WALK)
}