.PHONY: test quality dbt-build dbt-test lint clean

test:
	pytest -q

dbt-build:
	cd dbt && dbt build --profiles-dir .

dbt-test:
	cd dbt && dbt test --profiles-dir .

lint:
	sqlfluff lint dbt/models dbt/tests dbt/macros

quality: test lint dbt-build

clean:
	cd dbt && dbt clean
