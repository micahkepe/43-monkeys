# 43 Monkeys

In-development 2D pixel art rogue-like game made with Godot for COMP 460: Video
Game Design at Rice University.

<div align="center">
  <img src="./assets/images/post-demo-plan.png" alt="Game planning overview" width="100%">
</div>

## Overview

- A 2D top-down roguelike where players lead a growing squad of experimental
  monkeys escaping a high-tech science facility.
- Start as a lone monkey and battle through procedurally generated levels,
  rescuing monkeys with unique abilities to build a diverse, strategic squad.
- Find team upgrades to discover synergies and unlock powerful combo abilities,
  rewarding creative strategies!
- Beware—once a monkey runs out of health, it’s gone forever.
- Ascend through themed floors, face the mastermind scientist, and lead your
  monkey squad to freedom!

## Code Style and Documentation

- File documentation should follow the guidelines outlined in the Godot
  documentation [convention](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html).
  This allows for proper auto-generation of documentation.

> <details>
> <summary>Complete script example</summary>
>
> ```python
> extends Node2D
> ## A brief description of the class's role and functionality.
> ##
> ## The description of the script, what it can do,
> ## and any further detail.
> ##
> ## @tutorial:             https://example.com/tutorial_1
> ## @tutorial(Tutorial 2): https://example.com/tutorial_2
> ## @experimental
>
> ## The description of a signal.
> signal my_signal
>
> ## This is a description of the below enum.
> enum Direction {
> 	## Direction up.
> 	UP = 0,
> 	## Direction down.
> 	DOWN = 1,
> 	## Direction left.
> 	LEFT = 2,
> 	## Direction right.
> 	RIGHT = 3,
> }
>
> ## The description of a constant.
> const GRAVITY = 9.8
>
> ## The description of the variable v1.
> var v1
>
> ## This is a multiline description of the variable v2.[br]
> ## The type information below will be extracted for the documentation.
> var v2: int
>
> ## If the member has any annotation, the annotation should
> ## immediately precede it.
> @export
> var v3 := some_func()
>
>
> ## As the following function is documented, even though its name starts with
> ## an underscore, it will appear in the help window.
> func _fn(p1: int, p2: String) -> int:
> 	return 0
>
>
> # The below function isn't documented and its name starts with an underscore
> # so it will treated as private and will not be shown in the help window.
> func _internal() -> void:
> 	pass
>
>
> ## Documenting an inner class.
> ##
> ## The same rules apply here. The documentation must
> ## immediately precede the class definition.
> ##
> ## @tutorial: https://example.com/tutorial
> ## @experimental
> class Inner:
>
> 	## Inner class variable v4.
> 	var v4
>
>
> 	## Inner class function fn.
> 	func fn(): pass
> ```
>
> </details>

## References and Resources

- [Official Godot Documentation (Latest Stable Release)](https://docs.godotengine.org/en/stable/index.html)
- [Godot in 100 Seconds](https://www.youtube.com/watch?v=QKgTZWbwD1U)
- [Every 2D Node Explained in 9 Minutes!](https://www.youtube.com/watch?v=22VYNOtrcgM)
- [How to make a Video Game - Godot Beginner Tutorial](https://www.youtube.com/watch?v=LOhfqjmasi0&t=62s)
- [Godot 4 Crash Course for Beginners - GameDev 2D Top Down Tutorial](https://youtu.be/Luf2Kr5s3BM)
- [Flocking - AI for Game Development](https://www.oreilly.com/library/view/ai-for-game/0596005555/ch04.html)
- [Godot Shaders](https://godotshaders.com/)
