export type BossStat = {
	Base: number,
	Scale: number,
}

export type BossInfo = {
	Name: string,
	Image: string,
	RoomName: string,
	AIAggroRange: number,

	Stats: {
		[zombieName: string]: {
			Damage: BossStat,
			MaxHealthDamage?: BossStat,
			Speed: BossStat,
		}
	}
}
