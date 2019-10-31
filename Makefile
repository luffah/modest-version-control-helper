# all: docs tags

tags: docs
	vim -u NONE -c "helptags doc/ | qa!"

docs:
	mkdir -p doc
	vim -c "call genhelp#GenHelp('plugin/mvch.vim') | qa!"
