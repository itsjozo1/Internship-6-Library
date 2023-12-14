create table Countries (
    CountryId serial primary key,
    Name varchar(70) not null,
    Population int not null,
    AverageSalary decimal(10, 2) not null
);

create table Authors (
    AuthorId serial primary key,
    Name varchar(50) not null,
	Surname varchar(50) not null,
    DateOfBirth date not null,
    CountryID int references Countries(CountryId),
    Gender char(1)
);

create table Books (
    BookId serial primary key,
    Title varchar(100),
	ReleaseDate date not null,
    BookType varchar(50) check(BookType in ('Lektira', 'Umjetnička', 'Znanstvena', 'Biografija', 'Stručna'))
);

create table BookAuthors (
    BookAuthorId serial primary key,
    BookId int references Books(BookId),
    AuthorId int references Authors(AuthorId),
    AuthorshipType varchar(20) check(AuthorshipType in ('Glavni', 'Sporedni')) not null
);

create table Libraries (
    LibraryId serial primary key,
    Name varchar(100) not null,
    OpeningHour time not null,
	ClosingHour time not null
);

create table Employees (
    EmployeeID serial primary key,
    LibraryID int references Libraries(LibraryId),
    Name varchar(50) not null,
	Surname varchar(50) not null,
	Gender char(1)
);

create table Copies (
    CopyId serial primary key,
    BookId int references Books(BookId),
    LibraryId int references Libraries(LibraryId)
);
create table Users (
    UserId serial primary key,
    Name varchar(50) not null,
	Surname varchar(50) not null,
	Gender char(1)
);

create table BookLoans (
    LoanId serial primary key,
    CopyId int references Copies(CopyId),
    UserId int references Users(UserId),
    LoanDate date not null,
    ReturnDate date 
);


