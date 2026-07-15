<p align="center">
  <h1 align="center"><b>Server Authoritive Vehicle</b></h1>
  <p align="center">
    The client should own nothing and be happy
  </p>
</p>

## About

**Server Authoritive Vehicle** is a barebones, scalable and secure vehicle system for Roblox.

Every vehicle's physics is simulated by the server rather than the clients, each clients job is to send their inputs to the server and predict every cars future position to make up for the added network delay. This vehicle system focuses on having minimal data to replicate, making it ideal for games needing a light-weight chassis with the security and competitive benefits the server authority architecture and its built-in prediction provide.



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



## Known Bugs

* The gravity compensation logic causes the cars to sometimes (?) levitate into the air in public servers.
* The steering causes visible mispredictions.
* Cars pre-spawned in workspace sometimes (?) appear in different locations when you start a new server.
* Getting out of a car sometimes lets you see the void for a split second (?).


All of these issues are caused by Roblox's current Server Authority implementation.



## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
