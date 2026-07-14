<p align="center">
  <h1 align="center"><b>Server Authoritive Vehicle</b></h1>
  <p align="center">
    The client should own nothing and be happy
  </p>
</p>

## About

**Server Authoritive Vehicle** is a barebones, scalable and secure vehicle system for Roblox.

Every vehicle physics is simulated by the server rather than the clients, each clients job is to send their inputs to the server and predict every cars future position to make up for the network delay. This vehicle system focuses on having minimal data to replicate, making it ideal for games needing a light-weight chassis with the security and competitive benefits the server aUthority archetecture and its built-in prediction provide.



## Installation

1. Open the project in Roblox Studio.
2. Set `Workspace.AuthorityMode` to `Server`.
3. Parent `CarSystem` to `ReplicatedStorage`.
4. Parent `Vehicle` to `Workspace`.
5. Run the experience and test the vehicle in both Studio and a published server.

Your hierarchy should look like the following:

```text
Workspace
└── Vehicle

ReplicatedStorage
└── CarSystem
```

> [!IMPORTANT]
> `Workspace.AuthorityMode` must be set to `Server` for this system to work.



## Recommended Gravity

I suggest that you use a Workspace gravity value of `35`.

```lua
Workspace.Gravity = 35
```

This is recommended because although the system uses VectorForces to simulate the chassis at 35 studs/s², which in theory should produce the same results, it does not, resulting in the car tending to flip often.



## Known Bugs

* The gravity compensation logic leads to the car being flip prone (?)
* The cars sometimes (?) levitate into the air in public servers.
* The steering causes visible mispredictions.

All of these issues are caused by Roblox's current Server Authority implementation.



## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
