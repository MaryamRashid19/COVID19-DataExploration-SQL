/*
===================================================================================
	Project		: COVID-19 Data Exploration
	Author		: [Your Name]
	Date		: [Date]
	Tool Used	: SQL Server Management Studio (SSMS)
	Database	: PortfolioProject
	
	Description	: This project performs exploratory data analysis on global 
			  COVID-19 data covering deaths and vaccinations.
			  The dataset is sourced from Our World in Data 
			  (ourworldindata.org/covid-deaths) and spans from 
			  January 2020 onwards, covering 200+ countries.

	Skills Used	: Joins, CTEs, Temp Tables, Window Functions, 
			  Aggregate Functions, Data Type Conversion, Creating Views
===================================================================================
*/


-- ===================================================================================
-- SECTION 1: INITIAL DATA OVERVIEW
-- ===================================================================================

-- Quick look at the covid_deaths table filtered by valid continent entries
SELECT * 
FROM PortfolioProject..covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent


-- Selecting the core columns we will be working with throughout this project
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..covid_deaths
ORDER BY 1, 2


-- ===================================================================================
-- SECTION 2: DEATH ANALYSIS
-- ===================================================================================

-- Total Cases vs Total Deaths
-- Shows the likelihood of dying if you contract COVID-19 in a given country
-- Filter applied for Pakistan — change location filter as needed
SELECT 
	location, 
	date, 
	total_cases, 
	total_deaths, 
	(total_deaths * 1.0 / total_cases) * 100 AS DeathPercentage
FROM PortfolioProject..covid_deaths
WHERE location LIKE '%akistan%'
ORDER BY 1, 2


-- ===================================================================================
-- SECTION 3: INFECTION RATE ANALYSIS
-- ===================================================================================

-- Total Cases vs Population
-- Shows what percentage of a country's population has contracted COVID-19
-- Filter applied for Pakistan — change location filter as needed
SELECT 
	location, 
	population, 
	date, 
	total_cases, 
	(total_cases * 1.0 / population) * 100 AS PercentPopulationInfected
FROM PortfolioProject..covid_deaths
WHERE location LIKE '%akistan%'
ORDER BY 1, 2


-- Countries ranked by highest infection rate relative to their population
-- Uses MAX() to get the peak infection count per country
SELECT 
	location, 
	population,  
	MAX(total_cases) AS HighestInfectionCount, 
	MAX(total_cases * 1.0 / population) * 100 AS PercentPopulationInfected
FROM PortfolioProject..covid_deaths
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC


-- ===================================================================================
-- SECTION 4: DEATH COUNT ANALYSIS BY COUNTRY & CONTINENT
-- ===================================================================================

-- Countries ranked by total death count
-- continent IS NOT NULL filter removes continent-level aggregate rows from the dataset
SELECT 
	location, 
	continent, 
	MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, continent
ORDER BY TotalDeathCount DESC


-- Breaking down total death count by continent
-- Useful for high-level geographic comparison
SELECT 
	continent, 
	MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC


-- ===================================================================================
-- SECTION 5: GLOBAL NUMBERS
-- ===================================================================================

-- Global new cases and new deaths broken down by date
-- Uses new_cases and new_deaths (daily figures) instead of cumulative totals
-- to avoid double-counting across locations
SELECT 
	date, 
	SUM(new_cases) AS total_cases, 
	SUM(new_deaths) AS total_deaths, 
	SUM(new_deaths * 1.0) / SUM(new_cases) * 100 AS DeathPercentage
FROM PortfolioProject..covid_deaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1, 2


-- Grand total: Overall global cases, deaths, and death percentage
-- Removing the date GROUP BY gives us a single worldwide summary row
SELECT 
	SUM(new_cases) AS total_cases, 
	SUM(new_deaths) AS total_deaths, 
	SUM(new_deaths * 1.0) / SUM(new_cases) * 100 AS DeathPercentage
FROM PortfolioProject..covid_deaths
WHERE continent IS NOT NULL
ORDER BY 1, 2


-- ===================================================================================
-- SECTION 6: COVID VACCINATIONS — JOINING BOTH TABLES
-- ===================================================================================

-- Quick overview of the vaccinations table
SELECT * 
FROM PortfolioProject..covid_vacc


-- Joining covid_deaths and covid_vacc tables on location and date
-- This gives us a combined view of deaths and vaccination data
SELECT *
FROM PortfolioProject..covid_deaths dea
JOIN PortfolioProject..covid_vacc vac
	ON dea.location = vac.location
	AND dea.date = vac.date


-- Total population vs new vaccinations per day
-- Shows how many new vaccine doses were administered each day per country
SELECT 
	dea.continent, 
	dea.population, 
	dea.location, 
	dea.date, 
	vac.new_vaccinations
FROM PortfolioProject..covid_deaths dea
JOIN PortfolioProject..covid_vacc vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
-- Uncomment the line below to filter for a specific country
-- AND dea.location LIKE '%akis%'
ORDER BY 1, 2, 3 


-- ===================================================================================
-- SECTION 7: ROLLING VACCINATION COUNT (WINDOW FUNCTION)
-- ===================================================================================

-- Calculates a rolling/cumulative count of people vaccinated per country over time
-- PARTITION BY location ensures the count resets for each new country
-- ORDER BY date ensures vaccinations are accumulated in chronological order
SELECT 
	dea.continent, 
	dea.population, 
	dea.location, 
	dea.date, 
	vac.new_vaccinations, 
	SUM(vac.new_vaccinations) 
		OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccination
FROM PortfolioProject..covid_deaths dea
JOIN PortfolioProject..covid_vacc vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3 


-- ===================================================================================
-- SECTION 8: PERCENTAGE OF POPULATION VACCINATED
-- ===================================================================================

-- METHOD 1: Using a CTE (Common Table Expression)
-- CTE stores the rolling vaccination count, which we then use to calculate
-- the vaccination percentage — we can't reference an alias in the same SELECT,
-- hence the need for a CTE or Temp Table

WITH PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
AS
(
	SELECT 
		dea.continent,  
		dea.location, 
		dea.date, 
		dea.population,
		vac.new_vaccinations, 
		SUM(vac.new_vaccinations) 
			OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
	FROM PortfolioProject..covid_deaths dea
	JOIN PortfolioProject..covid_vacc vac
		ON dea.location = vac.location
		AND dea.date = vac.date
	WHERE dea.continent IS NOT NULL
)
-- Final SELECT: divides rolling vaccinated count by population to get percentage
SELECT *, (RollingPeopleVaccinated * 1.0 / population) * 100 AS PercentagePeopleVaccinated
FROM PopvsVac


-- ---------------------------------------------------------------------------------

-- METHOD 2: Using a Temp Table
-- Achieves the same result as the CTE above
-- Temp tables are useful when you need to reference the result multiple times
-- or perform further transformations on the data

CREATE TABLE #PercentPopulationVaccinated
(
	continent NVARCHAR(255),
	location NVARCHAR(255),
	date DATETIME,
	population BIGINT,
	new_vaccinations BIGINT,
	rollingpeoplevaccinated BIGINT
)

-- Inserting the rolled-up vaccination data into the temp table
INSERT INTO #PercentPopulationVaccinated
	SELECT 
		dea.continent,  
		dea.location, 
		dea.date, 
		dea.population,
		vac.new_vaccinations, 
		SUM(vac.new_vaccinations) 
			OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
	FROM PortfolioProject..covid_deaths dea
	JOIN PortfolioProject..covid_vacc vac
		ON dea.location = vac.location
		AND dea.date = vac.date
	-- Uncomment the line below to filter out continent-level rows
	-- WHERE dea.continent IS NOT NULL

-- Querying the temp table to calculate vaccination percentage
SELECT *, (RollingPeopleVaccinated * 1.0 / population) * 100 AS PercentagePeopleVaccinated
FROM #PercentPopulationVaccinated


-- ===================================================================================
-- SECTION 9: CREATING A VIEW FOR FUTURE VISUALIZATIONS
-- ===================================================================================

-- Storing the rolling vaccination query as a permanent View
-- This view can be directly connected to Tableau or other BI tools
-- for building dashboards and visualizations

USE PortfolioProject
GO 

CREATE VIEW PercentOfPopulationVaccinated AS
SELECT 
	dea.continent,  
	dea.location, 
	dea.date, 
	dea.population,
	vac.new_vaccinations, 
	SUM(vac.new_vaccinations) 
		OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM PortfolioProject..covid_deaths dea
JOIN PortfolioProject..covid_vacc vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL

-- Uncomment the line below to drop the view if it already exists before recreating
-- DROP VIEW IF EXISTS PercentOfPopulationVaccinated

-- Querying the view to verify it works correctly
SELECT * FROM PercentOfPopulationVaccinated