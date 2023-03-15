using Godot;

public partial class Player : CharacterBody2D	
{
	[Export]
	public int Speed { get; set; } = 400;

	public void GetInput()
	{

		Vector2 inputDirection = Input.GetVector("left", "right", "up", "down");
		Velocity = inputDirection * Speed;
	}

	public override void _PhysicsProcess(double delta)
	{
		GetInput();
		MoveAndSlide();
				
		var animatedSprite2D = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
		
		if (Velocity.X > 0)
		{
			animatedSprite2D.FlipH = true;
		}
		else if (Velocity.X < 0)
		{
			animatedSprite2D.FlipH = false;
		}
		
		//animatedSprite2D.FlipH = true;
		animatedSprite2D.Play();
	}
}
