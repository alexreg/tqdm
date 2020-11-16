# IMPORTANT: for compatibility with `python setup.py make [alias]`, ensure:
# 1. Every alias is preceded by @[+]make (eg: @make alias)
# 2. A maximum of one @make alias or command per line
# see: https://github.com/tqdm/py-make/issues/1

.PHONY:
	alltests
	all
	flake8
	test
	pytest
	testsetup
	testcoverage
	testperf
	testtimer
	distclean
	coverclean
	pre-commit
	prebuildclean
	clean
	toxclean
	installdev
	install
	build
	buildupload
	pypi
	snap
	docker
	help
	none
	run

help:
	@python setup.py make -p

alltests:
	@+make testcoverage
	@+make testperf
	@+make flake8
	@+make testsetup

all:
	@+make alltests
	@+make build

flake8:
	@+flake8 -j 8 --count --statistics --exit-zero .

test:
	TOX_SKIP_ENV=perf tox --skip-missing-interpreters -p all
	tox -e perf

pytest:
	pytest

testsetup:
	@make README.rst
	@make tqdm/tqdm.1
	@make tqdm/completion.sh
	python setup.py check --metadata --restructuredtext --strict
	python setup.py make none

testcoverage:
	@make coverclean
	pytest -k "not tests_perf" --cov=tqdm --cov-fail-under=80

testperf:
	# do not use coverage (which is extremely slow)
	pytest -k tests_perf

testtimer:
	pytest --durations=10

# another performance test, to check evolution across commits
testasv:
	# Test only the last 3 commits (quick test)
	asv run -j 8 HEAD~3..HEAD
	@make viewasv

testasvfull:
	# Test all the commits since the beginning (full test)
	asv run --skip-existing-commits -j 8 v1.0.0..HEAD
	@make testasv

viewasv:
	asv publish
	asv preview

tqdm/tqdm.1: .meta/.tqdm.1.md tqdm/cli.py tqdm/std.py
	# TODO: add to mkdocs.py
	python -m tqdm --help | tail -n+5 |\
    sed -r -e 's/\\/\\\\/g' \
      -e 's/^  (--.*)=<(.*)>  : (.*)$$/\n\\\1=*\2*\n: \3./' \
      -e 's/^  (--.*)  : (.*)$$/\n\\\1\n: \2./' \
      -e 's/  (-.*, )(--.*)  /\n\1\\\2\n: /' |\
    cat "$<" - |\
    pandoc -o "$@" -s -t man

tqdm/completion.sh: .meta/mkcompletion.py tqdm/std.py tqdm/cli.py
	@python .meta/mkcompletion.py

README.rst: .meta/.readme.rst tqdm/std.py tqdm/cli.py
	@python .meta/mkdocs.py

snapcraft.yaml: .meta/mksnap.py
	@python .meta/mksnap.py

.dockerignore:
	@+python -c "fd=open('.dockerignore', 'w'); fd.write('*\n!dist/*.whl\n')"

distclean:
	@+make coverclean
	@+make prebuildclean
	@+make clean
pre-commit:
	# quick sanity checks
	@make --no-print-directory testsetup
	flake8 -j 8 --count --statistics tqdm/ tests/ examples/
	pytest -qq -k "basic_overhead or not (perf or keras or pandas or monitoring)"
prebuildclean:
	@+python -c "import shutil; shutil.rmtree('build', True)"
	@+python -c "import shutil; shutil.rmtree('dist', True)"
	@+python -c "import shutil; shutil.rmtree('tqdm.egg-info', True)"
	@+python -c "import shutil; shutil.rmtree('.eggs', True)"
coverclean:
	@+python -c "import os; os.remove('.coverage') if os.path.exists('.coverage') else None"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('.coverage.*')]"
	@+python -c "import shutil; shutil.rmtree('tests/__pycache__', True)"
	@+python -c "import shutil; shutil.rmtree('benchmarks/__pycache__', True)"
	@+python -c "import shutil; shutil.rmtree('tqdm/__pycache__', True)"
	@+python -c "import shutil; shutil.rmtree('tqdm/contrib/__pycache__', True)"
	@+python -c "import shutil; shutil.rmtree('tqdm/examples/__pycache__', True)"
clean:
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('*.py[co]')]"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('tests/*.py[co]')]"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('benchmarks/*.py[co]')]"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('tqdm/*.py[co]')]"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('tqdm/contrib/*.py[co]')]"
	@+python -c "import os, glob; [os.remove(i) for i in glob.glob('tqdm/examples/*.py[co]')]"
toxclean:
	@+python -c "import shutil; shutil.rmtree('.tox', True)"


installdev:
	python setup.py develop --uninstall
	python setup.py develop
submodules:
	git clone git@github.com:tqdm/tqdm.wiki wiki
	git clone git@github.com:tqdm/tqdm.github.io docs
	git clone git@github.com:conda-forge/tqdm-feedstock feedstock
	cd feedstock && git remote add autotick-bot git@github.com:regro-cf-autotick-bot/tqdm-feedstock

install:
	python setup.py install

build:
	@make prebuildclean
	@make testsetup
	python setup.py sdist bdist_wheel
	# python setup.py bdist_wininst

pypi:
	twine upload dist/*

buildupload:
	@make build
	@make pypi

snap:
	@make -B snapcraft.yaml
	snapcraft
docker:
	@make .dockerignore
	@make coverclean
	@make clean
	docker build . -t tqdm/tqdm
	docker tag tqdm/tqdm:latest tqdm/tqdm:$(shell docker run -i --rm tqdm/tqdm -v)
none:
	# used for unit testing

run:
	python -Om tqdm --help
