# Futures

What are futures? - They represent single unit of work that will be done(eventually). Perfect for i/o based work, they enable Linux schedular like concurrency. Every future get's it's amount of time on the cpu. In the current implementation the futures are cooperative, meaning I don't have a timer that basically schedules future A is it reaches it's timeout for running(preemtive scheduling), which is the inferior type of scheduling.

### Disclaimer:

- The code here is far from perfect, it's messy, it isn't that clean. This is a personal project of mine to get more familiar with async runtimes like tokio(rust) and node.js. The goal of the project is to be eventually used in an async event loop(io_uring, epoll). It isn't meant to be used at production environments, but it could be used to draw ideas from.

### TODOs:

- Create catch block and if any error occurs it should be propagated over there. - done
- Create better deinit flow for each future that gets created - there is a ton of memory leaks right now. - done
- Try to make promises generic ? See how this works when combining with function pointers(does the compile automatically do type inference based on the generic and function signature ?) - out of scope, not feeling like doing it for now.
