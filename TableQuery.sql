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
    Title varchar(150) not null,
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
	DateOfBirth date not null,
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
	DateOfBirth date not null,
	Gender char(1)
);
create table Loans (
    LoanId serial primary key,
	LibraryId int references Libraries(LibraryId),
    UserId int references Users(UserId),
    LoanDate date not null,
    ReturnDate date,
	ReturnedDate date
);

create table LoansCopies(
	LoanId int references Loans(LoanId),
	CopyId int references Copies(CopyId)
);


CREATE OR REPLACE FUNCTION CheckAndSetReturnedDate()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ReturnedDate > NEW.LoanDate THEN
        NEW.ReturnedDate := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER SetReturnedDateToNull
BEFORE INSERT OR UPDATE ON Loans
FOR EACH ROW
EXECUTE FUNCTION CheckAndSetReturnedDate();


CREATE OR REPLACE FUNCTION SetReturnedDateDefault()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ReturnDate IS NULL THEN
        NEW.ReturnDate := NEW.LoanDate + INTERVAL '20 days';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER UpdateReturnedDate
BEFORE INSERT ON Loans
FOR EACH ROW
EXECUTE FUNCTION SetReturnedDateDefault();


CREATE OR REPLACE FUNCTION CheckBooksInLimit() 
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*)
        FROM Loans L
        JOIN LoansCopies LC ON L.LoanId = LC.LoanId
        WHERE LC.CopyId = NEW.CopyId AND L.ReturnedDate IS NULL) >= 3 THEN
        RAISE EXCEPTION 'User reached the maximum number of allowed copies on loan.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER CheckNumberOfLoanedBooks
BEFORE INSERT ON LoansCopies
FOR EACH ROW
EXECUTE FUNCTION CheckBooksInLimit();


CREATE OR REPLACE PROCEDURE LoanBook(p_CopyId int, p_UserId int)
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM LoansCopies LC
        JOIN Loans L ON LC.LoanId = L.LoanId
        WHERE LC.CopyId = p_CopyId AND L.ReturnedDate IS NULL
    ) THEN
        RAISE EXCEPTION 'Copy with ID % is already loaned.', p_CopyId;
    END IF;

    INSERT INTO Loans (LibraryId, UserId, LoanDate, ReturnDate)
    SELECT c.LibraryId, p_UserId, CURRENT_DATE, CURRENT_DATE + INTERVAL '20 days'
    FROM Copies c
    WHERE c.CopyId = p_CopyId;

    INSERT INTO LoansCopies (LoanId, CopyId)
    VALUES ((SELECT LoanId FROM Loans WHERE UserId = p_UserId AND LoanDate = CURRENT_DATE), p_CopyId);

    RAISE NOTICE 'Copy is loaned.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ExtendLoan(p_loan_id INTEGER, p_extension_days INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Loans
        WHERE LoanId = p_loan_id AND ReturnedDate IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Cannot extend loan for loan ID % because it has already been returned', p_loan_id;
    END IF;

    UPDATE Loans
    SET ReturnDate = ReturnDate + INTERVAL '1 day' * p_extension_days
    WHERE LoanId = p_loan_id;

    IF (SELECT ReturnDate > CURRENT_DATE + INTERVAL '60 days'
        FROM Loans
        WHERE LoanId = p_loan_id) THEN
        RAISE EXCEPTION 'Cannot extend loan for loan ID % beyond 60 days', p_loan_id;
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION CalculateFee(p_LoanId int) RETURNS DECIMAL AS $$
DECLARE
    late_fee DECIMAL := 0.0;
    p_LoanDate DATE;
    p_BookType VARCHAR(50);
    is_lektira BOOLEAN;
BEGIN
    SELECT L.LoanDate, B.BookType INTO p_LoanDate, p_BookType
    FROM Loans L
    JOIN Copies C ON L.LibraryId = C.LibraryId
    JOIN Books B ON C.BookId = B.BookId
    WHERE L.LoanId = p_LoanId;

    IF p_LoanDate IS NULL OR p_BookType IS NULL THEN
        RETURN 0.0; 
    END IF;

    is_lektira := (p_BookType = 'Lektira');

    FOR i IN 0..CASE
    	WHEN CURRENT_DATE - p_LoanDate < 0 THEN 0
		ELSE CURRENT_DATE - p_LoanDate
		END
    LOOP
        IF EXTRACT(MONTH FROM p_LoanDate + i * interval '1 day') BETWEEN 6 AND 9 THEN
            late_fee := late_fee + CASE 
				WHEN EXTRACT(ISODOW FROM p_LoanDate + i * interval '1 day') IN (6, 7) THEN 0.20 
				ELSE 0.40 
				END;
        ELSE
            late_fee := late_fee + CASE 
				WHEN is_lektira THEN 0.50
				WHEN EXTRACT(ISODOW FROM p_LoanDate + i * interval '1 day') IN (6, 7) THEN 0.20
				ELSE 0.30 
				END;
        END IF;
    END LOOP;

    RETURN late_fee; 
END;
$$ LANGUAGE plpgsql;


