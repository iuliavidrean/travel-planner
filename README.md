# TerraWise — Aplicație pentru planificarea călătoriilor

TerraWise este o aplicație pentru planificarea călătoriilor, cu backend în Spring Boot, frontend în Flutter și bază de date PostgreSQL pornită local prin Docker.

## Structura proiectului

travel-planner/
├── backend/
├── frontend/
└── docker-compose.yml


* backend/ conține aplicația Java / Spring Boot.
* frontend/ conține aplicația Flutter.
* docker-compose.yml este folosit pentru pornirea bazei de date PostgreSQL într-un container Docker.

## Cerințe pentru rulare

Pentru rularea locală sunt necesare:

* Docker Desktop instalat și pornit;
* Java 21, recomandat pentru a corespunde configurației din pom.xml;
* Flutter SDK;
* Google Chrome pentru rularea aplicației Flutter Web.

Nu este obligatorie instalarea globală a Maven, deoarece backend-ul include Maven Wrapper.

## Fișiere importante pentru configurare

Pentru rularea locală, cele mai importante fișiere sunt:

* docker-compose.yml — definește containerul PostgreSQL folosit de aplicație. În acest fișier sunt configurate baza de date, utilizatorul, parola, portul și volumul Docker.
* backend/src/main/resources/application.properties — fișier local folosit de backend pentru conectarea la PostgreSQL și pentru configurarea JWT, Geoapify și OpenRouteService.
* backend/src/main/resources/application.properties.example — fișier exemplu inclus în proiect, care arată ce proprietăți trebuie completate, fără chei reale sau date sensibile.

Fișierul docker-compose.yml pornește baza de date într-un container Docker, iar application.properties îi spune backend-ului cum să se conecteze la această bază de date.

Fișierul real application.properties nu este inclus în repository, deoarece poate conține chei API și valori sensibile.

## 1. Pornirea bazei de date PostgreSQL

Înainte de rularea comenzii, Docker Desktop trebuie să fie deschis.

Din folderul principal al proiectului se rulează:

docker compose up -d

Această comandă creează și pornește containerul PostgreSQL definit în docker-compose.yml. Dacă imaginea PostgreSQL nu există local, Docker o descarcă automat.

Configurația locală a bazei de date este:

Database: travelplanner
Username: tp_user
Password: tp_pass
Port: 5432

Schema bazei de date este creată și actualizată automat prin Hibernate/JPA, folosind proprietatea:

spring.jpa.hibernate.ddl-auto=update

Nu sunt necesare fișiere SQL obligatorii de tip seed sau migration. Tabelele sunt create pe baza entităților JPA din backend.

Pentru oprirea containerului se poate folosi:

docker compose down

## 2. Configurarea backend-ului

Backend-ul are nevoie de fișierul local:

backend/src/main/resources/application.properties

Pentru configurare, se folosește fișierul exemplu:

backend/src/main/resources/application.properties.example

Copiază fișierul application.properties.example și redenumește copia în:

application.properties

Apoi completează valorile necesare pentru:

* conexiunea la baza de date;
* secretul JWT;
* cheia API pentru Geoapify;
* cheia API pentru OpenRouteService.

Cheile reale trebuie păstrate doar local și nu trebuie încărcate pe GitHub.

## 3. Pornirea backend-ului

Din folderul principal al proiectului se intră în folderul backend:

cd backend

Apoi se rulează aplicația Spring Boot:

.\mvnw.cmd spring-boot:run

Backend-ul pornește local la adresa:

http://localhost:8080

La prima rulare, Maven Wrapper poate descărca automat versiunea Maven necesară.

## 4. Rularea testelor backend

Din folderul backend se poate rula:

.\mvnw.cmd clean test

Această comandă verifică build-ul backend-ului și rulează testele automate existente.

## 5. Pornirea frontend-ului web

Din folderul principal al proiectului se intră în folderul frontend:

cd frontend

Se descarcă dependențele Flutter:

flutter pub get

Apoi se pornește aplicația în Chrome:

flutter run -d chrome

Aplicația Flutter Web se deschide în browser pe un port local ales automat de Flutter.

## 6. Configurarea URL-ului către backend

Frontend-ul folosește adrese diferite în funcție de platformă:

Flutter Web / Desktop: http://localhost:8080
Android emulator: http://10.0.2.2:8080

Pentru Android emulator se folosește 10.0.2.2, deoarece localhost se referă la emulator, nu la calculatorul pe care rulează backend-ul.

## 7. Build pentru Flutter Web

Din folderul frontend se rulează:

flutter build web

Această comandă generează build-ul pentru versiunea web a aplicației.

## Pași rapizi pentru rulare locală

1. Deschide Docker Desktop.
2. Din folderul principal al proiectului, pornește baza de date:


docker compose up -d


3. Creează fișierul local application.properties pornind de la application.properties.example.
4. Completează în application.properties valorile necesare pentru baza de date, JWT, Geoapify și OpenRouteService.
5. Pornește backend-ul:

cd backend
.\mvnw.cmd spring-boot:run


6. Pornește frontend-ul:

cd frontend
flutter pub get
flutter run -d chrome

7. Deschide aplicația în browser și creează un utilizator nou.