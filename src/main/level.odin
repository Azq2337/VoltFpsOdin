package main

import rl "vendor:raylib"

ROOM_BOX_COUNT :: 5

ROOM_BOXES :: [ROOM_BOX_COUNT]Room_Box{
	{
		center    = {0, -0.5, 0},
		half_size = {10, 0.5, 15},
		color     = rl.LIGHTGRAY,
	},
	{
		center    = {-10.5, 2.5, 0},
		half_size = {0.5, 2.5, 15.5},
		color     = rl.GRAY,
	},
	{
		center    = {10.5, 2.5, 0},
		half_size = {0.5, 2.5, 15.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 2.5, -15.5},
		half_size = {10, 2.5, 0.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 2.5, 15.5},
		half_size = {10, 2.5, 0.5},
		color     = rl.GRAY,
	},
}

