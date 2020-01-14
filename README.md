
This generator does two things: 

1. Generates a Sprint Plan email (just a list of stories slotted for the iteration supplied)
2. Generates release CSVs (two CSVs with a list of stories planned for the given release, one for bugs, one for stories)

-----

To run the iteration plan generator, use a command like this:


```
  ruby ./generate.rb Sprint <<Iteration Number>>
```

For example

```
  ruby ./generate.rb Sprint 2019-24
```

will generate an interation plan email for Sprint 2019-24. It will be placed in the "sprints" folder with the name "sprint-plan-2019-24.html"

-----

To run the release plan CSV generator, use a command like this:

```
  ruby ./generate.rb Release <<Release Date>>
```

For example 

```
  ruby ./generate.rb Release 2020-1-12
```

will generate two CSVs based on issues tagged with label "Release 2020-01-12":

1. releases/2020-1-13-bugs.csv -- this is a list of all bugs in the given release, along with their zendesk links.
2. release/2020-1-13-stories.csv -- this is a list of all stories in the given release.

Please note -- there can be stories that were missed (epics are a particular candidate) -- so you may want to check github and double-check with the dev team.