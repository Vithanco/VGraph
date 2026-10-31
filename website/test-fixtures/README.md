Fixtures for the `?src=` browser tests. Served by the Playwright web server,
which serves this directory's parent; **not** copied to the website by
`deploy.sh`, which names the files it stages.

They are real files rather than intercepted routes on purpose: fulfilling a
same-origin request from the test driver while the wasm is still streaming
stalls the boot, and a real file also exercises the path a real `?src=` takes.
