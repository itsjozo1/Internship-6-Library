PGDMP  ,    ;                {            Library    16.1    16.0 X    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    16390    Library    DATABASE     u   CREATE DATABASE "Library" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
    DROP DATABASE "Library";
                postgres    false            �            1255    16757    calculatefee(integer)    FUNCTION     �  CREATE FUNCTION public.calculatefee(p_loanid integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
        RETURN 0.0; -- or any default value as per your requirement
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
$$;
 5   DROP FUNCTION public.calculatefee(p_loanid integer);
       public          postgres    false            �            1255    16762    checkandsetreturneddate()    FUNCTION     �   CREATE FUNCTION public.checkandsetreturneddate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.ReturnedDate > NEW.LoanDate THEN
        NEW.ReturnedDate := NULL;
    END IF;
    RETURN NEW;
END;
$$;
 0   DROP FUNCTION public.checkandsetreturneddate();
       public          postgres    false            �            1255    16751    checkbooksinlimit()    FUNCTION     �  CREATE FUNCTION public.checkbooksinlimit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT COUNT(*)
        FROM Loans L
        JOIN LoansCopies LC ON L.LoanId = LC.LoanId
        WHERE LC.CopyId = NEW.CopyId AND L.ReturnedDate IS NULL) >= 3 THEN
        RAISE EXCEPTION 'User reached the maximum number of allowed copies on loan.';
    END IF;

    RETURN NEW;
END;
$$;
 *   DROP FUNCTION public.checkbooksinlimit();
       public          postgres    false            �            1255    16756    extendloan(integer, integer)    FUNCTION     �  CREATE FUNCTION public.extendloan(p_loan_id integer, p_extension_days integer) RETURNS void
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
 N   DROP FUNCTION public.extendloan(p_loan_id integer, p_extension_days integer);
       public          postgres    false            �            1255    16755    loanbook(integer, integer) 	   PROCEDURE     �  CREATE PROCEDURE public.loanbook(IN p_copyid integer, IN p_userid integer)
    LANGUAGE plpgsql
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
$$;
 J   DROP PROCEDURE public.loanbook(IN p_copyid integer, IN p_userid integer);
       public          postgres    false            �            1255    16760    setreturneddatedefault()    FUNCTION     �   CREATE FUNCTION public.setreturneddatedefault() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.ReturnDate IS NULL THEN
        NEW.ReturnDate := NEW.LoanDate + INTERVAL '20 days';
    END IF;
    RETURN NEW;
END;
$$;
 /   DROP FUNCTION public.setreturneddatedefault();
       public          postgres    false            �            1259    16599    authors    TABLE     �   CREATE TABLE public.authors (
    authorid integer NOT NULL,
    name character varying(50) NOT NULL,
    surname character varying(50) NOT NULL,
    dateofbirth date NOT NULL,
    countryid integer,
    gender character(1)
);
    DROP TABLE public.authors;
       public         heap    postgres    false            �            1259    16598    authors_authorid_seq    SEQUENCE     �   CREATE SEQUENCE public.authors_authorid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.authors_authorid_seq;
       public          postgres    false    218            �           0    0    authors_authorid_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.authors_authorid_seq OWNED BY public.authors.authorid;
          public          postgres    false    217            �            1259    16619    bookauthors    TABLE     J  CREATE TABLE public.bookauthors (
    bookauthorid integer NOT NULL,
    bookid integer,
    authorid integer,
    authorshiptype character varying(20) NOT NULL,
    CONSTRAINT bookauthors_authorshiptype_check CHECK (((authorshiptype)::text = ANY ((ARRAY['Glavni'::character varying, 'Sporedni'::character varying])::text[])))
);
    DROP TABLE public.bookauthors;
       public         heap    postgres    false            �            1259    16618    bookauthors_bookauthorid_seq    SEQUENCE     �   CREATE SEQUENCE public.bookauthors_bookauthorid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.bookauthors_bookauthorid_seq;
       public          postgres    false    222            �           0    0    bookauthors_bookauthorid_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.bookauthors_bookauthorid_seq OWNED BY public.bookauthors.bookauthorid;
          public          postgres    false    221            �            1259    16611    books    TABLE     �  CREATE TABLE public.books (
    bookid integer NOT NULL,
    releasedate date NOT NULL,
    booktype character varying(50),
    title character varying(150) NOT NULL,
    CONSTRAINT books_booktype_check CHECK (((booktype)::text = ANY ((ARRAY['Lektira'::character varying, 'Umjetnička'::character varying, 'Znanstvena'::character varying, 'Biografija'::character varying, 'Stručna'::character varying])::text[])))
);
    DROP TABLE public.books;
       public         heap    postgres    false            �            1259    16610    books_bookid_seq    SEQUENCE     �   CREATE SEQUENCE public.books_bookid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.books_bookid_seq;
       public          postgres    false    220            �           0    0    books_bookid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.books_bookid_seq OWNED BY public.books.bookid;
          public          postgres    false    219            �            1259    16656    copies    TABLE     g   CREATE TABLE public.copies (
    copyid integer NOT NULL,
    bookid integer,
    libraryid integer
);
    DROP TABLE public.copies;
       public         heap    postgres    false            �            1259    16655    copies_copyid_seq    SEQUENCE     �   CREATE SEQUENCE public.copies_copyid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.copies_copyid_seq;
       public          postgres    false    228            �           0    0    copies_copyid_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.copies_copyid_seq OWNED BY public.copies.copyid;
          public          postgres    false    227            �            1259    16592 	   countries    TABLE     �   CREATE TABLE public.countries (
    countryid integer NOT NULL,
    name character varying(70) NOT NULL,
    population integer NOT NULL,
    averagesalary numeric(10,2) NOT NULL
);
    DROP TABLE public.countries;
       public         heap    postgres    false            �            1259    16591    countries_countryid_seq    SEQUENCE     �   CREATE SEQUENCE public.countries_countryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.countries_countryid_seq;
       public          postgres    false    216            �           0    0    countries_countryid_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.countries_countryid_seq OWNED BY public.countries.countryid;
          public          postgres    false    215            �            1259    16644 	   employees    TABLE     �   CREATE TABLE public.employees (
    employeeid integer NOT NULL,
    libraryid integer,
    name character varying(50) NOT NULL,
    surname character varying(50) NOT NULL,
    gender character(1),
    dateofbirth date NOT NULL
);
    DROP TABLE public.employees;
       public         heap    postgres    false            �            1259    16643    employees_employeeid_seq    SEQUENCE     �   CREATE SEQUENCE public.employees_employeeid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.employees_employeeid_seq;
       public          postgres    false    226            �           0    0    employees_employeeid_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.employees_employeeid_seq OWNED BY public.employees.employeeid;
          public          postgres    false    225            �            1259    16637 	   libraries    TABLE     �   CREATE TABLE public.libraries (
    libraryid integer NOT NULL,
    name character varying(100) NOT NULL,
    openinghour time without time zone NOT NULL,
    closinghour time without time zone NOT NULL
);
    DROP TABLE public.libraries;
       public         heap    postgres    false            �            1259    16636    libraries_libraryid_seq    SEQUENCE     �   CREATE SEQUENCE public.libraries_libraryid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.libraries_libraryid_seq;
       public          postgres    false    224            �           0    0    libraries_libraryid_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.libraries_libraryid_seq OWNED BY public.libraries.libraryid;
          public          postgres    false    223            �            1259    16720    loans    TABLE     �   CREATE TABLE public.loans (
    loanid integer NOT NULL,
    libraryid integer,
    userid integer,
    loandate date NOT NULL,
    returneddate date,
    returndate date
);
    DROP TABLE public.loans;
       public         heap    postgres    false            �            1259    16719    loans_loanid_seq    SEQUENCE     �   CREATE SEQUENCE public.loans_loanid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.loans_loanid_seq;
       public          postgres    false    232            �           0    0    loans_loanid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.loans_loanid_seq OWNED BY public.loans.loanid;
          public          postgres    false    231            �            1259    16736    loanscopies    TABLE     L   CREATE TABLE public.loanscopies (
    loanid integer,
    copyid integer
);
    DROP TABLE public.loanscopies;
       public         heap    postgres    false            �            1259    16673    users    TABLE     �   CREATE TABLE public.users (
    userid integer NOT NULL,
    name character varying(50) NOT NULL,
    surname character varying(50) NOT NULL,
    gender character(1),
    dateofbirth date NOT NULL
);
    DROP TABLE public.users;
       public         heap    postgres    false            �            1259    16672    users_userid_seq    SEQUENCE     �   CREATE SEQUENCE public.users_userid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.users_userid_seq;
       public          postgres    false    230            �           0    0    users_userid_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.users_userid_seq OWNED BY public.users.userid;
          public          postgres    false    229            �           2604    16602    authors authorid    DEFAULT     t   ALTER TABLE ONLY public.authors ALTER COLUMN authorid SET DEFAULT nextval('public.authors_authorid_seq'::regclass);
 ?   ALTER TABLE public.authors ALTER COLUMN authorid DROP DEFAULT;
       public          postgres    false    217    218    218            �           2604    16622    bookauthors bookauthorid    DEFAULT     �   ALTER TABLE ONLY public.bookauthors ALTER COLUMN bookauthorid SET DEFAULT nextval('public.bookauthors_bookauthorid_seq'::regclass);
 G   ALTER TABLE public.bookauthors ALTER COLUMN bookauthorid DROP DEFAULT;
       public          postgres    false    221    222    222            �           2604    16614    books bookid    DEFAULT     l   ALTER TABLE ONLY public.books ALTER COLUMN bookid SET DEFAULT nextval('public.books_bookid_seq'::regclass);
 ;   ALTER TABLE public.books ALTER COLUMN bookid DROP DEFAULT;
       public          postgres    false    220    219    220            �           2604    16659    copies copyid    DEFAULT     n   ALTER TABLE ONLY public.copies ALTER COLUMN copyid SET DEFAULT nextval('public.copies_copyid_seq'::regclass);
 <   ALTER TABLE public.copies ALTER COLUMN copyid DROP DEFAULT;
       public          postgres    false    228    227    228            �           2604    16595    countries countryid    DEFAULT     z   ALTER TABLE ONLY public.countries ALTER COLUMN countryid SET DEFAULT nextval('public.countries_countryid_seq'::regclass);
 B   ALTER TABLE public.countries ALTER COLUMN countryid DROP DEFAULT;
       public          postgres    false    215    216    216            �           2604    16647    employees employeeid    DEFAULT     |   ALTER TABLE ONLY public.employees ALTER COLUMN employeeid SET DEFAULT nextval('public.employees_employeeid_seq'::regclass);
 C   ALTER TABLE public.employees ALTER COLUMN employeeid DROP DEFAULT;
       public          postgres    false    225    226    226            �           2604    16640    libraries libraryid    DEFAULT     z   ALTER TABLE ONLY public.libraries ALTER COLUMN libraryid SET DEFAULT nextval('public.libraries_libraryid_seq'::regclass);
 B   ALTER TABLE public.libraries ALTER COLUMN libraryid DROP DEFAULT;
       public          postgres    false    223    224    224            �           2604    16723    loans loanid    DEFAULT     l   ALTER TABLE ONLY public.loans ALTER COLUMN loanid SET DEFAULT nextval('public.loans_loanid_seq'::regclass);
 ;   ALTER TABLE public.loans ALTER COLUMN loanid DROP DEFAULT;
       public          postgres    false    232    231    232            �           2604    16676    users userid    DEFAULT     l   ALTER TABLE ONLY public.users ALTER COLUMN userid SET DEFAULT nextval('public.users_userid_seq'::regclass);
 ;   ALTER TABLE public.users ALTER COLUMN userid DROP DEFAULT;
       public          postgres    false    230    229    230            w          0    16599    authors 
   TABLE DATA           Z   COPY public.authors (authorid, name, surname, dateofbirth, countryid, gender) FROM stdin;
    public          postgres    false    218    t       {          0    16619    bookauthors 
   TABLE DATA           U   COPY public.bookauthors (bookauthorid, bookid, authorid, authorshiptype) FROM stdin;
    public          postgres    false    222   ؉       y          0    16611    books 
   TABLE DATA           E   COPY public.books (bookid, releasedate, booktype, title) FROM stdin;
    public          postgres    false    220   D�       �          0    16656    copies 
   TABLE DATA           ;   COPY public.copies (copyid, bookid, libraryid) FROM stdin;
    public          postgres    false    228   :�       u          0    16592 	   countries 
   TABLE DATA           O   COPY public.countries (countryid, name, population, averagesalary) FROM stdin;
    public          postgres    false    216   �&                0    16644 	   employees 
   TABLE DATA           ^   COPY public.employees (employeeid, libraryid, name, surname, gender, dateofbirth) FROM stdin;
    public          postgres    false    226   �,      }          0    16637 	   libraries 
   TABLE DATA           N   COPY public.libraries (libraryid, name, openinghour, closinghour) FROM stdin;
    public          postgres    false    224   �7      �          0    16720    loans 
   TABLE DATA           ^   COPY public.loans (loanid, libraryid, userid, loandate, returneddate, returndate) FROM stdin;
    public          postgres    false    232   :      �          0    16736    loanscopies 
   TABLE DATA           5   COPY public.loanscopies (loanid, copyid) FROM stdin;
    public          postgres    false    233   &      �          0    16673    users 
   TABLE DATA           K   COPY public.users (userid, name, surname, gender, dateofbirth) FROM stdin;
    public          postgres    false    230   C      �           0    0    authors_authorid_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.authors_authorid_seq', 1, false);
          public          postgres    false    217            �           0    0    bookauthors_bookauthorid_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.bookauthors_bookauthorid_seq', 1, false);
          public          postgres    false    221            �           0    0    books_bookid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.books_bookid_seq', 1, false);
          public          postgres    false    219            �           0    0    copies_copyid_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.copies_copyid_seq', 1, false);
          public          postgres    false    227            �           0    0    countries_countryid_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.countries_countryid_seq', 1, false);
          public          postgres    false    215            �           0    0    employees_employeeid_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.employees_employeeid_seq', 1, false);
          public          postgres    false    225            �           0    0    libraries_libraryid_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.libraries_libraryid_seq', 1, false);
          public          postgres    false    223            �           0    0    loans_loanid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.loans_loanid_seq', 1, false);
          public          postgres    false    231            �           0    0    users_userid_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.users_userid_seq', 1, false);
          public          postgres    false    229            �           2606    16604    authors authors_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (authorid);
 >   ALTER TABLE ONLY public.authors DROP CONSTRAINT authors_pkey;
       public            postgres    false    218            �           2606    16625    bookauthors bookauthors_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.bookauthors
    ADD CONSTRAINT bookauthors_pkey PRIMARY KEY (bookauthorid);
 F   ALTER TABLE ONLY public.bookauthors DROP CONSTRAINT bookauthors_pkey;
       public            postgres    false    222            �           2606    16617    books books_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (bookid);
 :   ALTER TABLE ONLY public.books DROP CONSTRAINT books_pkey;
       public            postgres    false    220            �           2606    16661    copies copies_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_pkey PRIMARY KEY (copyid);
 <   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_pkey;
       public            postgres    false    228            �           2606    16597    countries countries_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (countryid);
 B   ALTER TABLE ONLY public.countries DROP CONSTRAINT countries_pkey;
       public            postgres    false    216            �           2606    16649    employees employees_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (employeeid);
 B   ALTER TABLE ONLY public.employees DROP CONSTRAINT employees_pkey;
       public            postgres    false    226            �           2606    16642    libraries libraries_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.libraries
    ADD CONSTRAINT libraries_pkey PRIMARY KEY (libraryid);
 B   ALTER TABLE ONLY public.libraries DROP CONSTRAINT libraries_pkey;
       public            postgres    false    224            �           2606    16725    loans loans_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (loanid);
 :   ALTER TABLE ONLY public.loans DROP CONSTRAINT loans_pkey;
       public            postgres    false    232            �           2606    16678    users users_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (userid);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    230            �           2620    16752 $   loanscopies checknumberofloanedbooks    TRIGGER     �   CREATE TRIGGER checknumberofloanedbooks BEFORE INSERT ON public.loanscopies FOR EACH ROW EXECUTE FUNCTION public.checkbooksinlimit();
 =   DROP TRIGGER checknumberofloanedbooks ON public.loanscopies;
       public          postgres    false    233    234            �           2620    16763    loans setreturneddatetonull    TRIGGER     �   CREATE TRIGGER setreturneddatetonull BEFORE INSERT OR UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.checkandsetreturneddate();
 4   DROP TRIGGER setreturneddatetonull ON public.loans;
       public          postgres    false    232    236            �           2620    16761    loans updatereturneddate    TRIGGER        CREATE TRIGGER updatereturneddate BEFORE INSERT ON public.loans FOR EACH ROW EXECUTE FUNCTION public.setreturneddatedefault();
 1   DROP TRIGGER updatereturneddate ON public.loans;
       public          postgres    false    232    237            �           2606    16605    authors authors_countryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_countryid_fkey FOREIGN KEY (countryid) REFERENCES public.countries(countryid);
 H   ALTER TABLE ONLY public.authors DROP CONSTRAINT authors_countryid_fkey;
       public          postgres    false    216    218    3527            �           2606    16631 %   bookauthors bookauthors_authorid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.bookauthors
    ADD CONSTRAINT bookauthors_authorid_fkey FOREIGN KEY (authorid) REFERENCES public.authors(authorid);
 O   ALTER TABLE ONLY public.bookauthors DROP CONSTRAINT bookauthors_authorid_fkey;
       public          postgres    false    222    218    3529            �           2606    16626 #   bookauthors bookauthors_bookid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.bookauthors
    ADD CONSTRAINT bookauthors_bookid_fkey FOREIGN KEY (bookid) REFERENCES public.books(bookid);
 M   ALTER TABLE ONLY public.bookauthors DROP CONSTRAINT bookauthors_bookid_fkey;
       public          postgres    false    220    3531    222            �           2606    16662    copies copies_bookid_fkey    FK CONSTRAINT     {   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_bookid_fkey FOREIGN KEY (bookid) REFERENCES public.books(bookid);
 C   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_bookid_fkey;
       public          postgres    false    220    3531    228            �           2606    16667    copies copies_libraryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.copies
    ADD CONSTRAINT copies_libraryid_fkey FOREIGN KEY (libraryid) REFERENCES public.libraries(libraryid);
 F   ALTER TABLE ONLY public.copies DROP CONSTRAINT copies_libraryid_fkey;
       public          postgres    false    224    228    3535            �           2606    16650 "   employees employees_libraryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_libraryid_fkey FOREIGN KEY (libraryid) REFERENCES public.libraries(libraryid);
 L   ALTER TABLE ONLY public.employees DROP CONSTRAINT employees_libraryid_fkey;
       public          postgres    false    3535    226    224            �           2606    16726    loans loans_libraryid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_libraryid_fkey FOREIGN KEY (libraryid) REFERENCES public.libraries(libraryid);
 D   ALTER TABLE ONLY public.loans DROP CONSTRAINT loans_libraryid_fkey;
       public          postgres    false    232    224    3535            �           2606    16731    loans loans_userid_fkey    FK CONSTRAINT     y   ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_userid_fkey FOREIGN KEY (userid) REFERENCES public.users(userid);
 A   ALTER TABLE ONLY public.loans DROP CONSTRAINT loans_userid_fkey;
       public          postgres    false    3541    232    230            �           2606    16744 #   loanscopies loanscopies_copyid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.loanscopies
    ADD CONSTRAINT loanscopies_copyid_fkey FOREIGN KEY (copyid) REFERENCES public.copies(copyid);
 M   ALTER TABLE ONLY public.loanscopies DROP CONSTRAINT loanscopies_copyid_fkey;
       public          postgres    false    228    233    3539            �           2606    16739 #   loanscopies loanscopies_loanid_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.loanscopies
    ADD CONSTRAINT loanscopies_loanid_fkey FOREIGN KEY (loanid) REFERENCES public.loans(loanid);
 M   ALTER TABLE ONLY public.loanscopies DROP CONSTRAINT loanscopies_loanid_fkey;
       public          postgres    false    232    3543    233            w      x�MZ�v�8�]�_ѻZ�	�Ϭ��tڙ۝�]�7�KQ����m��_}o�M=�h��q�� ss��8���a8����i֝������;��|~4_\<~΋Ӭ>�sS����0Ϯ��2������inOmf���~R��y��?}��.x�f�Yu�&/̿��T������k��@�_�S�,wP��MXn��N�j��Nmnr��Ic~���s��~'+tvxZdFhͥ[��h��qy��4�6;�Z��<o�{׻P�ome���3�u���	�て����<��M�s�xF��O���6�n�C��b3�i_7ޜ-F��o<G�Xau��
�ċ����mK�%�M�a�9��_���{o.\%ӑզ.yT�6�+�ҙ�ayw�0gy-;FD�2H�À�M�	�AjKә���="�|գ[,'/ZBﰭ�2���oH���l��ݴ<v�ɋ:��`�G�������� �2s6����%t���?A�o݄�_8�;fv3� 2�q������m�S���OH���F�?�D	^��c�Ad�y�t�z���+�yz�e�s�s�V�\��<���m�<��5<��q�y��5"���2�@cG�b�?ø���v�"��ԭ)KT�{5�G)��ҳث4Xn�3}xy1�q�^��y��2�5M�u�ʳa����a�_&0����A���{�N�c~xT��{��&�,, ֚Z*�(��
P{�Z�p�@F�+��&�n^��]��u␦K�)�Ee���3��)0�]�F+T����_���V�DP��M�3?�Xd
��4��̔�A��U߇��f�Q�\K�c���w��_F��f��v_�p��Е��p$Rޏy�yGx��jMY�@en�!y(�"��nJ�S�4J⺴槛��un���}��䶐SY�
�Y������[؁>�>14�C��e%��\�ɍail�e������*3w|;�m����A������H��
AwO�|A�"�Nf���U��s���i\��"��>�6+�����k�`�2Nr���|���.t�*C�����;hiJI�nh9�qr��J@	��0�9x��E��ڃ=R0�a�a�K-��4�� s���<ϫ�O �6���{X�dr�:+I!�O�J��V�Z�����~�x'�"���T�9��]/�}�+���V�_n#hr�[-R>G�����e<0��[��K��<?�����w�[�
�� ��qAw�l	�s�SJ*$�9	�Jl��a|ߠOIv�O�s�
۰5��\:&��Ϛ9����4�Ta�Z��˼�=��VB
XH�����Џ�9��X�eE<�������ǉ�F��I��� 7z6�\�r�\NT���A�}r�/��R$����<vq�9 ���/�č֕�њ�5Zw�r�̯�|�NF���R�Qjp�D�V���D����x ��9Aפ�o�<�5��}���~#DȄ)�I]����"/m�:)T=�WyД���Z���݉���� ���h.�8M�V
,�D`��v�ع��V;7�KMc~�K��kW�j�,:�ȱt�u�U Rq�	K���щ���#� �����T��6C��������9D���� ��8 mwq�����@�=�55�^ȗ��/�b���,W���9������U�zA��)m���D���QY��&J��ڰ�� ��B�B��n�kwΉ�F�m�y�,��tI��t�/Xį�o����J����3�p��@��j��8��VC1�-l� po���C�5a����CQF0�M\y�h����ڕ��K�9k�9��6,7�i��O�����*��AYH��Dу�6.� ���|��\@�M�?W�� O��E��2S��FD��5S��RXb���Y��wb+�I��9�?���a��y�r���V����v���~)X2 ���B9�o�Al����$�[d;֓n���i��<u��vݩ�@`G��6d
)����N^D��
�c�Aa\A�c�sz-��vT�U�[�Mr3�� Qw��ժ��e�"�r���a/��y��Q�I!929>�+�3�Q(Pf�=ՑCd!���f�����+S�B��Tz���s����)l�*4�sd�J����R �)���� q��x���aA'�����
�3�MR�EZ���λ��Qk��r�6� |��{�ߨ�3�$C:��Ԟ�J-4&��Y<�>S�K�VD%IP&�"�d?b�������%
��c͟v
�ܻ�%2��qi*b�w�%��9��t�]��R ��,i*B��]j��R-�D����W*.�&}�T� :o��!^�0y����՟��%�� ��1D�XB��)�*���>����o�Q�QD�[n������������-�O?U�`ц���)�Z_<-�[����sir���¹U�ݝ��}/��\Ne	.>��XT!�sߋ�`��4�q������ju��Fgٳ��s�H�=4��-T�t�P6�a�n�;쾸�4T6d�g�#�Ja��a�$��Z}��X���wb[.G� s$�A%|+��<�7!�z�%� �.>�6P��^��)�R�l�[m��2b�L�I����@��[�I��xX�뒔)t���q�#t���J�x�O����^�	���Y'6/�֠8�y�w��Z�V�Kq`���*��@ �Z�)��~��EGr�8�V�#�0�E����wB�KCQ��
n�in\��9�:l���<o�Q��������x��R�[6b炔�D'u�*�*si�k�R�wk��H�ݯEdǼk�!"n��g69AH�)���O�ӛ� ѵ���ЖR���������Z�u�#��� �=��Q'[,�R-(�Cv;s�r��v7X@,
I����q�;O�mӤAܥ�����s&�c<6i�%]���a�����9P*%F
�"#�˙�=[*�����$~�>���ü�EN��m�rEk�څ>D�!B��J��RJMPN8� ��?�J�Y���R��eg������P��F^�}��Xd�������w�Qpdwa��/��K*�)J�������=�}A�9q�My�4T$�27�2��g���8,��pf�n�j"5K�m��W^ՠC�qMUu�u�&�,]]7��xe%���P��V^�],�n�k��2��d��iB�����pJe��� �b��jV���`Y0��=_���ذ>���Ё?�C��� ?�[��F�P)�P�n?� ~q��-r)ٳ<U�_n�(�7I2� �itK�ر�S��,S7��=lPĨ�'�o�4�2KӞND����������S�K�V]|��{#������5łm9S��=u����2������(�a�.A>�L�C���̜Ax�����}�"� �ۅW�v2����!A<�Z:�-u/D�%�	�:�B��R�bm9a����	�͒#�N�BM�����.�qH:�$R+��a�Ѯ-��&�h����[��T���q�*T�@�_���z�{�ȣ�X�����	����t���N9���#��Z<�j��]������?��H��d��s��;�v����/ׁdA�4è=GP���'�$��2�'���zd>���"+(�y�4����;��#&�_�@n5�]��h��y�bŉ�x^#�x�a�Ø�Rvɑ�jk �3�D��/��5�����$��%�[�0�46�H�2��ć�>&�c�8��<a��r9�j_[�� 8K�Y��yn��Z��&s�"�6[>SRܣ=��ȉ\fxM��F�'�b�⹥V^�q���"�Rv�˱�s�T���`k�K#�?d�"Y4�t#qO��C�cɝ���D��D\��(�%28��*�|�u\�e���`�,��	��^��H���]#B�Ğ����/u�J���q��G�_�D���"����]�W�x8�G��F��0��Ve�k� �����h.c�>;�w1�}P��V�3ۼ��Бӝ۽j!Um��ڜ^b:��;[� �  <)?�Z�7L��G)��������Zw�Cn���4��N���f�V�2�rL����j�T�E��%�	��xL1U��-`[?��*y�Ƚ)KNVA�����a��kuD����}�D�����ϙ�����d��q?�&� PH��nF�f���*$j��P.�P�@q�{�;0��#�\�B����m;u���{�W
��A$���H��� �l���5�����j��d��p԰���d�鍙�(��8�C����e��a~�W^.8�������W���ܣ�ѩ:B�h� y�r֖*���B�b?�L�{m���J^C�[��"���kw�h�̤�d�:�/<xc=O*�I�5�@�Էh�w~���Qe�ߊ�rG��M��|��h��{�q�-)d����6KCK�۲H7[?�[:+[�R��۷��Gt�t����Ew�������Zo�ALz�kv6Bb�3��EbQ)�?�5�jF���ȼu5:���"S:��3;�F����eb�Bkv�:ps��(�&}pщ��pbh@{���v�=W4W��$&�"8ΞˣR�:}�B��vԽ׽�vUg:��G

�	��d��sP!-C&Y�T`�k�> �~Py���K�n���,�^D嫑ɥڥ� �naxW�ָ��Z����&��0h?��<���Ɔ���
n�_����`��>;J�?����<��c/<y�:�� ��RP�XX��P{@T�f�8◫ss�=�]0��!G�T����P�gLp��̳�R,tUg�J��3�/�7
��񶪐B��E�f;bHeF�n���h� 7��Q����@�	*�WC�G��#G5��q�X	���"ɼ���~�'D+PsNt'���s�݋w� �Y��Ċ�W��XQ�V�;�퐀�4	裚�
����s �O�7ZD<xW>��pp�-��z��x��K�������k�q`#i�T?X������SA����A�(!��ӻ!+H%�9�P9:.�?%��p�P@,�1]r�/4.�-�,?���H������exXg�2��pi�"v��y�W�S(Mf�Ux���[� �݅�%���BZ$=�B�1#�X��"�m�Y:��8w��N�l�@uL�N6����"CFm�KtB�b�������$��6�}-TX��ѯx��c$����4�V�
���n�(y�����L�R�]��`�������)"]��T��#�H�h�%&+jy��᭤����>����]�c�9X�~����Ş~^ _��2"����T.��%v����|ٴ�  Ni,�����ye�4@�/�O3fv��x�u�N��z�c�ވ�lp�P�O������J��s"�E,��&��&����OA}܅�n��1?����c�q-7)�?V�|�WH�F���. ��=@�mM�[��񚓒�O�X��[?�H���ONN��r�      {      x�e�K�l;l��ucl��x �c i�������6+���9:��|�E�ʧ�����o����������S?m�OY����?���g����F��i����}�؀�|���}~��aĘ��Xs����m{Ͽa��g����O�i��K��ۚ�4٢��5��J�4��Б��m�KGi�Z�������t��l%�ѡ�&���w������m�?�ig1d�Z>}�&m���]}=�D6������q��)��-��)m�Zl.��>��-gS7�Ww,�|洩d{v���i�.m6�v�[�-��KoͶg�P�m�n��KeW�X�#��|>��o��J٭�)�*{1��&W�Y�ϔC�p���׺-��P���:�7��{���C��6l7\��o"��,�}���WI�c[斓1�(JyU` e��oK�Lk-[�gR=�2Jd؊�g������`{�3���6h��Ʋq�V�mv�c��|'3U��7esNS��dk�{춿�b:�X�3��i��Ͱ�m�� �G��2u��ꐦ���*���-2d��0DU�L����4Q���E������wG��c��-�b��m���4�C��u���4M~�]T��.�۹��+ �n"�6��gŜ��^�l�����Q�cfRK}Wd��L(O4���wT�l�iveŷLL:Ӽ灹��W*Mi�ٲ��`�;
�m0)�KL�W�׃]�-K�c�����c6��]Gb�l*:��aֽ���+!���x0�6���k2Mܩ������چ�|���s7Z-Z/%Me[h��'�-��w4ai��s56.���)j/�b_ñ�X�3VK>L��zHD;mu�f�;�Rc�4�3{z4a[l�]�X�/3LY������|R�&���gc���~�"��4L�u�|���������OT�b�m�USaz�s~��0��;�qݔ ��U�W�̸3�:��ڍ��F�݈�O�k��K�9�f�9�L8��/ْ�б����[i�v���{�u��tT�D4QLᦩᒖ���:��l�����c���S�]F.7�,A��a%z�������w�x����M����&��ߡ�c����Cֳ������Ή^&Ff*w�e[X��e��hZ?^ֶ_��=���k������;���������;Vb��\�T�	lt���f�c"�c�<������u2/2�k�,b��A��dw`3������6�a�1��eW��%��u�F ��B(3�˃2	�mߦIx�ݠ�����qU�`Sj0ψ=���=�/a��mm1�����p/���L�&,b�h ��O;��NWlr�F�M��Б��Ԉ
ٕ�'�o�}�g�f�>� "�*����%��ӻ�&��q������"�c�aF7b.�m�+�b����E$U�hI�����Su����M� �GN�.���=��M��{����힏t35�}�t� q�bU|�M�+3Gaf����QM���>z��%X�v�0
�	�@�3�+�w`+t6nO�R�A�GQ���#q��k�԰��<i��y<�)SWH����
���ѭ@\��h���*:�/������C8ݹ��D�9~���?�ɶc:D|�0B��7/SP<�M��!;�W�g�f����j|"LQ��b�MT'AG5�<p8:9F�����s����\�*b��Y�c�ՃBa?�V"�#*&L�'��Է4v� $��m<�G�Ɨ��Ř �Mgu�\��p��(7R�)���D�h�X ��6����+]z������V�&�;�O�J$���d�W�eӉ�b��@ �8ZdAT���ჹ�^0z�6� E�l��ga��.�!`�63�����7iiS@I�_D}���qU�Nc�T�m+��@d��F���؅UM*и���~����1���m��25��J�!��Ә�\����9s� ��w`�i^׭P W�_�ii��x�=~ٴN�
��v�!�ʰ���@���U�=�ɶ�N�$����6Ӆ�� s��G�g���{n���$ӈ9G��wB�9A��i�`��M���[qDS�R�I�t�85^�^�UΣ9y�����'q���@��=�<@w4�EOg
��G�=��	ʥ�M�J:d3]�,U�$t�m3����7}�عD	�����W.g�w�풟��F�`'��� �SH�gg��&�>E	wp�aѰ.�.F�8� �=��h��쾆#�ᦫ�G�V/�|X��E3G�V�~H��R�Nl�=��ӳ&]^ne���9�0:N�Gh�6߉�7iJ7%0O4�br5����#'ވ�
ӂǽ��n�9x&	%m�i��t4�yla�ڬ�%]7{���i�3�)dh���#�*����A#"3}a�H�m�U�`hLD�9-|��Mu�KR���v7k���G���2��h��1��L��`W�Z.�����N������j�mz��h����&��5$D�X����8��ύ }���v���Th��p�m:WX�W9��c	B�����4|'M�5F����`����sÌ%��\�}7�,�J����&�s.
�DP ~�oK�$G�C�ь4�y�b� g<�r`�tv>�o�`g�'�m9�RC;�߽I��,i��������MvD�I�R������Z'م[{R�s��Q�/A��'�!GO2�H��8�����v����:�*9�&߆��Z"�g`Ir��6������K�K�F4dd	�4�G�/(�'>�T��@r��ot;jdQ��n� ��p��'b5�Jzc&ҷ{vx%V��p$
z���Ҍ*hm�j���^"�R�TH��;>�Ġ�M\�.IXk�UY�ne�*�q̌�����x�sV�6BH�-��m��	�lP�~㖱�+5�TH`����)�q��m�Ý��+yG�~��JJ\$g�{(龰#S��@�����g����� ����MK�����;م5tk^og&#�ѩLM�3$����纸.M��.4�_�쀮�[r��CfW�b��\u{����Ё���$��2��]�u��wl�r�ɮ�]|S-�Ox�(m׮�tvՠ��9��8�QSv�	�-�tH2�Zѩ<9���'�ld���M����`�M�x&��c.� q��yXb�\�8�n�x�	�/#��~�5�j���-�|x�\6%U�:�@!��lSH܏S$��.��}F��t�6�K��1]|���ґ�(n�Nt":F�Y�W
��G�!�3B���Inu��A�Ԁa��9�{7�s�^r���4Q��SaT�8K)�anjH�������9��$���5�k��v��.͐?0�6*�\���3u��sx��mi���I���{X�l� *��b��;�w�~+:>�)�dh;X�Ʉl�$�xR�ɟ����~�B��Lhc�TH�4����ei4�~R���?�}8��s���&`Q�ս��F�#�(]��j3�
�F�ʪo?����S���G�?O��if��h�4��u��%�;��$�&E꒚��%�߼�#����M�(��`�V&������_LXe�ᔁ<��L��X q�R)եM�xj.b��w2��7�Z�:?��p�Kz��K	b5v;הQ��UD����;�**+�ɼ<�.��T�9��Ii4j�C��	0a��F�m��]
�gA�i{Ω.z�\,�B)}iʖ�8k�b�q����X�i��ft��9��� �M�E��s8G�6m/H���a�&���rʷ�$�*Mmf��@%�n
����D3?����$�ۣ�4�ye���,_�9�+�)e���\ɗNjۆ��[~n��t#Jm�*�F��GY$�C�����Qj|�0;����䄆WZR&�}K��f{��&��WTW���/�@z>Z����G$�#i�j�?1�sʡ��{��Nh�[�*��R�Б���ߡ^Q-%Ќ�������St�+M��t�O�a�Å���'�f��n��C;��������ȩ�����	0 g���jt�H�o��[}�Ks'�>1o�7��)磑	�4]+�����1fϭ~�/��<V ;xrg0 W  "�ȍ8U��0Cn�C�����e<S��]-O�=�/�����"�ht���XuNr�-���#T��<$���5�>=��>"��oN���p��œ��}G�5��a@j��U:���|��Kpƍz�IUBj2�H�q_H�������R ���
��Y%�&.'�7U\�p���4�za�ۏ*�G!>�訔ָ��f��s%�T�����#�7��bo�D=���#�{צ�bZ�%ϩ��e�(�F3�~�5@r�:�G�������Q5�7�>��������q`EH�XO�/��E��s��<�\�VX�����O��#�m<��)'^��M/�/<��t;�\��x���/��E�-V�4X����ȟ4U��T�$k/h�S���4��$'�
ŴMox��'��-���m��d�����W�������qQ�o.R���O�mz��`U� ?A.�2��\�KP.q|���x�u*�Y;.XY������4h�[M�����̦�I��O���'�Q�4�kV��\�x���_�c[�^�MhSq��w�/��s䷩�~k����,e��§�/n+��V�TR����T�L�[Q�Q�/{����J0���vf��j/ԭ5kx�U�"�T�h��m�M��q67b�5/��VY�&����i�[��R���/�R�m���ɢ(�􌞚W�m�ޮy+�t.�$,�F#>�1"���{��N�0ׅ����*��m��j��EX�һ*���5�k]��*a~�
�pk���Z�ɬ�34������1O�0����%�����ђ����8�k��JPe���dyr�h��k�`�z�u.�S�/\��i�9����(����H�����zi
���e��I1���qّ�_�V!J>v�G����%�<V{p��w�p�����[w�ȸ�J3=��^6�S��5��b(/���{;��ki6~�x�����.���;kd9���c��?��ڶFNk*��_�e]L�o�[dQ�,@�g��H�s�٠m�K2��l��<oզ����M�WY9��^��i���1�#w%��yH�+4L�Xe�a��l/�:9c�qҩ$y��
�'�G�2� h�Sd}�y0�	^���[���7�#�oS�e�@���n���o7�V��˼��l��R/��l�0�w.�%�L�G�y�̓dD6u�#�4��}�=��6���C��>��R���ٷ�}�G�5/��{{�yJI��3�Gr�t0/�!���T�a��͋�j���?��FW���OJ>l�-<33n����wA�N�E��'����Y3����r�Mf���J�8�\/��6�AK�y�8�0zmv&�����#&i�)��{Gz4�5��_����@�|�&��O�Ӣ�kb�M���@)l
^h��)����QsO����c+�N�CԟR���q����G��f��q��Vy�|R���!s�j���y�t��?�H#2ܧ�HW����T;/7�2ۅ�U�M���Sv����x+����5J<�@q�~۟ȁ���#�tx�}2>?�t�=����8�P6kV���*%u��3��j��<65^] �r�~�"=�ajB=�-z]F81�~޶�<2�xp�TW�spؤ�߆�V��s���)X<�h;k���}֨o��{�U>D�&![��C��3]�X���������c��GEaX�[8�m���kx!�?��cx����ڃo~ni���&��A:�yr
�bG���.�N�ء���p�4�U���r�]O��Y�1������w\���I�{�Gȋ�?Z0r5�q�k�|p�-?:=&6�c2*= ��S�t ��t�8{9�.y���IX����CK%��:�3n9a�NۣMIC��d	ϼ�S
���RB�.�ܓc���������!�P�{�)�C��y}��\.��$�S�/�ӟ9: fX�/�.6y[�e�2�^,*#�~�G�j��.k������}��5:���j�!�}R��l�d[2g��Z)J8�����.�I�Lzxd���[��jg���[����zJc��,ϦZ&���������s�&xrH83Vkʎe�	'�N��k�~~� ���OZ�_�9P�9����'�% 4`�����7D�      y      x��}�r#ǒ���M�e&V#�@m��YdY�&�bK6� $RHd@� ��ϲ`V�m���,��ε1�Ͱ?l�{D$2���{%�$2��~��q��M0M��q�do~.eY7���o+�,UU��|��K5
14����8~s��J���7Wz��G-K�w�+q����n���(�B\;�k�4U����+_�Bm����V�c&���EO-q�qT�vQ���*h���(������0�]�B.���A��R�]\y�L�\�U�Wx,Y.�e�ǀn-����U=�s٨�h��x��G����H�u��s]��)�M�|3��[>��.d-�m�P��ߕ�7��`L�|��K\�^����>�����3}�7��� ƀp?���E5e�����sr��Z�X�78
h��S~������^Wⲭ��Ӏ�)�n�Xԃ�Ini���}���l���!����F�f.�K+nt[���
Nk�F4��d7���f���k�|�I���[��Z(�ѥ��KY6��b�./<�w�|��۷���-��qƓ���F|n��'�V�S^�{��~*��u���%6Y@��4�a�=�Ո�|--pBćJ��(䥥e�Q����܈S|�l0�r��8���N���wK��d��}n�3U�iҢ'/zڿ�9�Cn6���ɣ���fS�ʇ����wP�e���o��-G!-}������4��m[�"z/.�}��v��bҲG�����M�Y[6��v"5��"��v��Ҁ�(̺k����Z��j�E����ʛQH�:����ݢ.�R�\|�����{q��� ʘ�Q��܊;�{�2w*�yӰ	���xk��|�^�	��k���5��D��a@O�s�}����	K.h�M����_���Y����[1�B���:���>i�Q�Tm�2��L�|r�����6/hD����cF�[�	�{7����`Q�v0L�r�*&�ك�������$NʇK0�Rkr���70ދ�G���?�w��O����p~"���+��*��(�%�D�z����n�ŧR=�[��m�K;Sk�0Ӟ;ѵ��i�uS1E�#���.�l%��`Vjl�bv�L�񓂱��,t��I�)	ӉIj��F1�4�}z�x��V�)o`�e���o��˅~���:��	$��R��p�?T�{�|��(�ŏ3:�0����y�䯸���(���y����}���cYΕ��GqB�nL3z�;�A��횋��?��"��"��?��)nh�|+w��*��ӢO������WE-���=�W��@w��
4=��U��:m��|َbZ�(&�#л8�N�״�w˼n0�{_��B�3z��dl�HF���1�q:ġƁW�$0�6��J��5��!��Ix��)��»�*�G�T��`UO[��I�3a�?!�I[���(�i�Ny�F}�u�u��	��kF	ߘe쟮C%�&�o�y~�{Ohɢ�oqꏬ�\-�$�}�p�0���8���?��(qG6���_� ���kUaf��������n,Eim\J뒌�ƅ Q��J��l��������t����8ih=LL+�ǵ��7�TJMyb��`6 ��x����W�2��A�[��;����T�,/�6oG�F��*�F%�v����>�I ������>]�-��Y>4�����P��.t��U1J3�uhOx_����+ne�����9ƞ�������ɢ׍8"w7o��u��J�`U�?JY�8l���+��Gf��������S�c��S�4[���cr���8�4�ˊf��(�����n6J-�D�Ƕ\mGӔ7ؤ��7�؝���lh>���{��v��+$�*W4��D�����8X���0�j�;�%c����@��v?��#;�k���yN~� Hw�'����A�`��1�l��g�\͉�Y	��0�{a�Bx���=q�����{f������; ������7D{�QDiv�dl��H�iأ��z�5B�=�n�N����(�����;������P� �NB;CY���p�⬭O 8(G������׺j0�P��b�ج;��?St8񨷕ގ&�����= �/��8:�p����ۇ4G��6���p�#���2HX�;�`�^��\Krw�,�Z��L;��l��K��
���K�&l�ck�����F9x��&t�C�'�!��yR���w�*�hJ+��w�&�Z�&D�f��� ���Q?Z�D���Q~�6�����~"�*n���~�Z�J!Z�3y�("�vSNɣ	��`~1�g��5p�M+Y�F��
k�%�b���K;!�)z蟂�9���,��MwQP�a�3�H����6�CL���
�X?������!r>ޖr�7x�� �N���4�@�q��X��5TSr���8�jT3
�c{�a(jiE�u-��!��qh9�OB[���,%�G����0����c��bkrp_�sbH"Z�����3맪�3�>ҋ-Ʊ	N�6���ǅ�%��X����<�㰛���9��`L����~ $\h:��Rc��B�ָ�J��OR\QH�5�ek�oo�a���F;��Q 	s�k(�ސ�������P�Ǔ�_8��)վ�*��mk���#C
�{�,���Hw�b�Wң�������;��°>A��ĖD�8V5"���A��NAw[�s@�0��� �Яc���8��8b�LV���%22���:z��r��J��]��C��D�6�i�#~�a]������n�$�� �?�B��!_p��`Y�j��	�6|�� ]\��-�F��9�o�+�������p�����Fo0'!s	�Z"�!���}���1fZ�N�Yƹۊ���"�^lk�7��g5 �b���Gtq���@�Sfе0��cC8�L-E[��uԩ,�0�3JijC�^�W�dU��2�q�] }�0��ͬ�-U0����c��P[E�0��5�nGp������mu�����{Ȑ���z�*�%�Ǒ,r�2�g~�l���
�� �5�+&��J�aV��EbO�aEb�~�a�u����QQhi�t+X�y�$�(Ë�/�@�UN�ym֗�������;�U���� �/U��#�W�[ �|-X%f� �M�`Ǫ���g�k�Ɔ~A�Z��x�\#�PdIJ���#�9��F\�4��*�5'fw҄z���(�>H~\H��\��2_?�A�E��(8�h��r�K��t�f�Kp0��R����U����:�������A	=���[�bK⌈&�W٧a�(-���@p���R���0�)q[���Ė�� ���٥(�N���%�I!�!:��Xk���� �0|�����d<T����&��}C��^����0m�5�x���g���!��y,�[c�o�<�y�=�;+]�bM68Ǎ��UN�K�vژy��!�8�0���S�������v���'���M�ݿ�g-�U��G��\��G����dÙ��x�^���X�ăJ7
&P{gK����ќ(����vĩQ�� ��&x�EK7[��F�z:)�{�/�^	��0iŮ���5>�_�ٶ����??��p�E@���FC���O���B|Ğ���)`��ȟJ���d��(+��\0a�۳��v�3T�n���PO��L��|�	e`�e�p��X�3��d��'{��_�[�@�!U��+8[�(�0&���#_P|�i�c�6 ���pD���y�g#�V��B]�G"<�45��!aw(�v7�W;_uSl񲱓��¼]��H'�ƃ����c�ȕ��f� �s��h��g-"�����ƻxx置
%��\���N�>�:xa9�+� �|T�5 mC"1�3�iã
��\��0,2����TZ��;���m���W�[������vѱ!s����By���w�؍I��0�Q	g� �P;�E���E�n�a���V�r�B,��ӄ���?Ⱥ��ƐIg�{��6���%F�lj    �������J{3oqѷ-�z6#�LU��*`X?d��)�^~�{�k��L�K���2��&�hO0��{>97���|YP2%`�(q���=�r��cK�r|ٻ��翖5�jAG �� ��=nU��y�kC'��$˿z�ݵzʉ^��'�
|�]�Q�
�ǧWoa�n��zf��$3�a�ފ_���B�8����v�t���n�9�9��������ujYt
�v{Vm5?���'�i���4�<�ɢ����U���\�W�܅��4����қ"��F16ɉ���X���$C1<��_]�� D��#��١�d�3�k4�rފ��
Lņ=��C0~s(>�k(�~ BG�a2ib�d�Z�6|S�s���R�[`�/��&Lc��0�泖 �F��8�<Y��G8�;���p�oK ��.
l����Xl��iZ&^���t�&G]�녷V�$���V� �����)���^֦���� �#Sqt���E��/o�A�����p䕎�;�0.�\U4d�n���a�Y�Nѭ7�%A '�`ڈn5�[ʾ��P��ѩ��	�ݓ���,1
�Ĩw�TQ����]�~�(j"U
�Ļe�GkL�+/߽{�@��^8d�)�l��Ͽ���:���`�6��	J���)#��Q���YyO_IKF/I�c"��N0(1q����W!����$߾S^PA�e��I��a�:���W���2ꪐuFIdeS�}k�����"��g6�ư4��C��a����#�����X(woLő�cx����nPh��E>�z?�AB*RʄQ�l�Y7Y�5�[3��Ͽ~`w'ݳ2�s��?�2�R"R�#�~+0��&៌1���� ���IR{�<�[��~��N*�)��2$󧦞��)�Z,�*Z��cף�	�$f7N���de.q5�o��>�wv)���"�����йX����@$!S7)3�>u��'�	'/[�)bpd�BS/尅Ƀ�t���ʄ�?)qLath���
;��?P:Nlr$x�WaB�b�tj���-�⎄@�C��q$~�[�ľ�ԝP@F�½35�E��M|NC�:��n��j��hj��{Ąa���i	���~���
��N�Lɸ��X\�e�(�:��+22z�Ժ�ǂ�
��=D�̬������a+��:

1��3�
��T9�7����vQmHQr�g�c��8ǽ-�ְo�h�9Y ���OVMaGn'��فv2��*d������o���N��b�����)Rj������=���Im^��)�ך ��!`�g����UR�䴃�0�^>�z�4�(d�O�쮗�j�v]Z���;������i�d'+����~K�Z~a���RP�XcLd���E�����>�������4豦J0sJ!����K�
˃�\�O�t$�����QXR�W�#�#ot| 3A����U�(�2�$����6 ���(�R� �%fiK2G1k��Y�����{�Q�qꏷ��'���o�ȼB��������C�����fA�"���]�VU������&��"�Kb-)�Db�0�s���'[��f�%�'��ǖ��I���1<���~R9�1���M���$�P��0&��w�g/�H�J���%��V�(�d~MY�z�W-	r��vB��| 3f�H����0��,�w�~�|Ζ��������2b^f��Y�lT�|�c�0�?�R?����^{��ʴ������ݻSd}u�8���A��f�x��Z��&��E,��l�:<�s�4�#?3P�Q i�l�ݯp'��Il����i�I;!
p��������EVѻ�mEb�e	(�ԫο$|l$Ḍ�RLΉ�Yxx��K~��Z���|���U��:�P}�����b0����xMXإ`��Q���� r��W��T�x�,�l4"\z��u������Ղ���-#S=6���9�S��lؔq҇-|��o�oL~�P;�j�{�0w��{/,'��[6&B?S�2����N��F�ߋ���p�L����*��د�O��/��U,d�T?��Y���W�4 �jȬb(F�6�ր��옉��]�0�,�	����&@�w��N�;yP\dW��Bf~�llz��6�.�׼zptLȌEv��+�bCI)� ~zćƣp��ݓ����圬��x���5:�	@Cf{2�l�-�q��6�lR�T&��D����[��H�T��\%�t��� 5N��ܔ��a���I�+���s]�A��S��r��Pl��w��YGD5)�0w)6��#z��
KKH����C���=*��Ȧ�=e�'N�,���β� 猘�!�h<�Y�ćntF �g[�Q/KRd,0~W��b�������R���*#����h�+u�; 1'����و�Y� sB�G�K1���k�l4~�צ���;������[�.`��R$1�m<�F7O��3��(d9�_Fu~/LdBⲚ� p���X!��ƙ5�����`��=��9	OK��j.�0t�I��R�јe*��2���D�:�'��5`�8{�+I���������T뉝
�c�G�^-i\������*�����
c[8Я�ȩ�&�B��*H�X!1ʪ���H,�	��e�������K�~j�NCi�Gf���駂����@��0��$>�up`�U�`�W�'��o:���������Ͽ?`�[^
�C�}� =�\��X�Wr��'V%F��兮(�ij���%^5�gM"-�yž+��K��v��r��TD��UQFH��EQ+�0�;�S�OdK��R��у$�}
��/��}�r%�Q����{̼ ɡ"�w�|V�B�h�`-���M��{bY�R?J�i�7;"i2$9ԙ�"'��Q�\Rh�~4F�4��F/�`��$Ѕ�߇�&�iddB�~�h�� ��b�f��E[��{j����[_��p7�#�Q��X(2cwNἬ	�\�iK�.�t�MJ��;�G��XnQHv�h\�#�2Y��ʆJ��av������M�tz+_n�������d�.�
��Y�(��%H`�1Y�$T��~��R�F�_�''&��5�D���Z�sZ�C��XR4�_��"H9b�i��*�n#�_G�-eN����;�`$}��=�fib��[o�{�{EO�;���]�:�����]�[��X(������ED�b�$���B�5o�~M���(3���B��р���4~�f���0b�)l*n��$�G�
*��ވ����_����OR�ING�0eck�u�?�P\]�D�ӵ��p��:;X���ؕ�Nq
�i.a9R������1��9��-!�����;��q�DP���J�(	l4���)�ŏdXH�jٻ��Q<���Y�[������6����������̒W��bX[�Z��	6]�2��N��Μ��"Ƹ�.�سg�U.���v��|jߊ��9e��Ș����&�����Y�u�t��G!�~�O[��-���
:>If���+X%��X�#����;qݖ�xz�'�ڮ���o�����V9�۽<���wݮx��V���7��.�(b�Q��R��� Z�S���g5cG�:���c/�"�8��=9V:(��mA԰ޚ�q��z�ć�F?@Z���3��[R��ĤK��wer� �y���'8o_��Ѥ|g����	��h��&v���K��k�~wR`�R�%�C�B~�o��+b�*dE{/c�)�����tL�;zw���T0mr���D3U�>釴g���K!Q6�-U�"���>�+��t˚L�aqp�lI֘�9�KYsa�q���D�QX�dS!>��&.5F��~�����D��Ŕ���bO��>O\Ry�lkW�1K�V��b2�DGW�;5~�.�y��Dg�_QD����������*�B��ݭO�$Y�M����2�5ԱW���3A���cR9� f��4e�,�1W�2��W�R�k�)��|��Y'�P�J�h!>!�}��n�%K�����"5���B0X��YK�Km���W���q�D    �P|�SN�:LP�qf#�8�d<���_���A;a��w�0�U6��y�7���
��5���ll� �\p*��5�����В3��K�金�f3M&�L:j�vR�hb�C�w:�v���]21����&̣�Nfǁ��	W��,��]���V���V�u�ӏ�N������VJ1&g%R8� ���b����,0���Gb��9�x��Ί&�@����B6�CS{r�a9����MmuE��Nʹ�6 ��
5URJ�t,vmR�P4gZ��F�Xj��w����}1���S[�m�1�N�sF��-u5�88:p��Ro0<4��I�uI���@j污�G<�+F��g��4�HU#z��PO���IE��NSW��j%���إe��'�M������֔�+��n=�U�}�*��Ɑ��v@G|)���I<���5;��;����YS:|A�\�q{��*/j�o
�6�x��V3n���E�x�Oũ�y����%,�k���å�1���-詉+.�!���k��I8���[|*������\���z����'�$�ҝ���R��5�1`��g�/Hs��^R�o2wyÅ�e[��X��Z�5ו�Ei�+Uq����cW��[�?Z5%v��S.~�_4������ �C��k:��Q�����4��s嘑��͆�$�L-����b��<`���l�^h�Z�(26�Qlm���)�qb�" F�O�o��}4}�J%{پ3]l��+������KQK��B�n-������*�~msΠ��'���V�>FUW�3���-��s	Ecy��|�\G,�����wN?R����И	�ԝ�����@��1���%0>�:���]y-�$P��XN�"�h��XjY������%�4f!���C6�Le�>6i&C�x|%/�����Rظ��g ��j1�ճ#������)2��*#�L���8��9�m{(sQ��͕S��ţA*~"��t���%�jd�+�c����}�Lř���3R�-�r��*E�'w�B��PU��Frd�����4���1 ���߉�Dx���ǉm(A�����;��ĉ)�<�TB�\P6��s�P�����"���R.��n;�:h;(��ܝ"F�C!kzR�� ���B~�;�u����i=��1�<�W� |�B?}#�]̼�8�9��Dl�cv�AG��lW8H�pi����qM� ' �g�)��i��L�D����t-��W8L��A_�ƍy�HBA�8�"0����y��N���s:��_�5b��nn��=PN�()ׅ%v�$V%b*u�4]�|S8/���P0%vN|G�򹘙�,�����u*[��QG��	�Y���L FMW�،��94�&s�� @��&԰�4�c.$qk�\j\�:hjT�Pӆ�ߋz�g�pf@Y5�g䢓t�|2�%��T)�Y#Ν'���z	�K9����8B�����J'шSW�x��W��n�b��@�Bl:�-Q��J�S>	�b�`V|�M諗�֔N��?�z���V"zi9�8s~o�q�3�qR����jۻU���û[���7"v�Tp&�����(�ᰯ	����~�	�,�np{�P�n����:(|i�N	�t*b�18�#y&�C�BQ�Zw���n� j���)E�j��8)�{3<�3���D����i�;�Yg:S@�֥��(��Ð�	��\%�ŧ|��4(=�G�x���@��H�c�%N���?	�A-�����H�V��ڞ���翬���ԕ&E�S������(ʧ��Zt��-�
��{P�b�Mq"�8��^�%��Ș��0��6�z�Z�Oje�&�_`1�|�F9N,뫧�`�I d���vh^��m?��5�@��{_��[H-�Ru�iaq��8B?1�a�[<3&�)�_�O4 |�5a��x��j��"O-mx���w�N����z2_��ؘl��z�l?���m��~�ځ3�ލ� ��3�&�'�ر��D0csX�o?'����Cq �*U3�KL:fl� �t��J���NM$�����jsǪ��=�v'�QIl���aUTIR���{�q�F�Sr�iIƁѲ���ˇ���#�`[0*�@:Pn�ӭ�X��٠�Q��/�p�3�. ������+6v��X���p4$ѯ�F�^�^���'���>/1݂^4�C%׹+0LL���F˞��������^�S%<�K�޹m��O�F4i�iđ�j�!O��-��ׯ���Ω��:\:���>,H�g�B�P���~<	�qM=��K�km��r�X�JEZ���#���	�_8^4R������������3?�=}�67m�:��t���� �+�-
HIC���B�s���c�s9��K�����Ė��h���Y,v9o��I���[<�jc�ל�u��h{��IL��ץZc��;�I��5/�3����I�����c)�0Խ䎥S���w�4����Ŗ�r�!5��T2;JL3������0�ò$�a�����<:���M�3�\Aw-n0.���_��Eo:��,P9�"����cmcS���8\`'��)����ʒ�eK��L�|� �%%I�ÿ��|в�Δ��A���i>�7�����y��+ 2�E��+`K���`>q�(u�M-?��-簲V��ݷ�����Ω�2*��7/� [dtI�u�X.�?aph��!���9�6�9����Hæ\U��iN�Z�:�S�`&��	_���u9��I�zC�-��ԙ��~Zދ�&���W�a>W�X����2�Q��q=��N�p�j:���`��P���5�'e�2Ӓ����llc*�:����v-�q��.3��Aα)�>����A���`Y���-��xl
�5/v��������*N>�O�{cT쯍�Ѱw�����K�o��a�g�3�\tc�i´��ivw���zKR$��[����0��=ۮ���>#a�(N�~i����z� �۪��>ƻ���(�1�VB�D��s|nj��~~��_�&�L���� ^� 9"N��hd���/�q�qcRD�r�f`H��{w$�9U���f��sQ�5�����X�͆i^�X"��pb��=I\���MI�A�n�2a���L�q�+�@������e�nV�.�Q�Ϊ'N�1,r��ܽ�	�䕤fd�-%>j�C�K��@EI2���x�Rt���'p=�����+->\�F�}
����4U��8�r_gZ�/��ESIß��Hy �G����Jw����>"���Gǵq���~�׆����>Ij����W��06�Ko���Զ�s~�xtp����$u������*&p��FJ�a.�TVF�`��`\��kJ���P��k��;�%#�P����qr/�ݐ��_��� �ťgAh��/�G	�F��LT�v"�$s+6��bʞ�)ǈ]�y�R�|�Qi�a��o�XF�<(�e���
YJw[<�s��ls�yL�T��s�H�2b;��������U�t ž}�^ؚ=ʂ�vG���G��I,�V���n�-=��W��*Cz��/}��g%@���6'՘87e�A�ݽ�S�Z��a���8l��B����dTi^�@/Z`�bj�R�D�z��n�	SJ�9��ϣ��~kvCM��K^�l򦁻���ʢ���ؖj�ҽ�]F�dť�Y����]8r�sCm���J��|պ�}2��Z�;.����(�+nz �N%��7�`�?�昜��7]߮~�"�C/FD�^���l�ϲ��Rb����w[��
K��tj�2��ݖ�v��p*�Z��?[��NL�i�3~�?��Z�	����b��L�O�,��+km9
h�cP��P�J�#ڲ�������V�Z���!�۴�C:�(��1�����R.3%�J�ҥ��!)Cc��dX\����G�&5����cכضɽ2�3���2���^(}٣�rR֌�Q�����2�f�ą�QH��J��<?����G��}ҕ��f��g_j�B�O��? �  �Rǉ�.��&]�R�^�PQ��:�Qʌ��Z�#��Cϯ�a��c�c�kq��o��ۢ1�.�����{�E��k��4Gw���!�wB�O
�n����) <�E�%;�Q��m�:0;d���)r#�5�%�?���A%�	#]��ö�bX|�W3{�^�ϒt��9�ܖ
�6��$�\rkR���H��d(���/O���i��:>�^Pb�v�����?��4�(Hz9�]W�c]~OzՖz*����N�]oր	�b��(�r8M|"�n1A�zh�ԢT��v;Ȍ��S0z}p-M���a�Z]���@��c��Ɛ<�m�0�J�;��Sful�f71�	[��1ܹ����[x��d����ík�!N_{C`��{9oL���/�!�*��E��S�. ���zyմ8�{�����k#15�J_rj����$�6�̑�C�X�YϩB.�5�'qQ������_�RЫ	��;%}Y�k�?��E�pV��礑{�Q4���Tw��og!s9�5�S3ۯp��t��u��k=��k��8�덠�m�X�;]��7���F�(�c�3I��~�!n�6����؈��a7-�U��T�9��.�F��sh��a�-���}`��v�\���b��kj��X�o.Kg��G�>ic�&"5��uh����֖�
�I��	 �v_l_0�������J#�5=��w\�;��>�J�a]6�h,{� �n+���oj���pT�G��@�Ka��G�k���`P:�b_�4J���5��S7��>�w�3�]!�Z���*K���f(�i���1������Z�"�g���k�!�B���R��_�	[�U��z܄F�g'�X���`��x�Z�|�$}�x���{D�q�责)�[er!��J���x�ĦW;���]�ȀRKzh��4�E���U��׎|��OK���8|�)b���NL��eF��4�ͭ=�E��(�34&[�gw�[��=�o� �Ƚ�������<$�#ŴKf�r|��?ĺ���1�v�����N�&֨M�:s\��I�x7�)�E���B/s���_3�M�h�ze�6�{']͎?Gz��!5�_:��>����/H�T>/zW2e�&��h�-���Π�f�I/>��8�[�p�rXL�!s�!��=6��]iW�f�������4.�C���\a�d`%�r���{ԏ���.�4�[��52o�F3=1
�~C���H���b��vvk�L(�;��utO2���d��A`� 0]����=�T[�f.79l�|�m<&cB�<Cu.N�*�i�e�Oh
�=�5���& �ٗ����A�����0W3�ȱx��D�p��:���4a�1�k�Jj�ؐ�w��8�?*Zz~�ڰ�e�w���7/-��ʔ�pΖ;.'>�E��>�iN\�u>,^���i�޸d��������޻�Ug$�Tb'�%&V�|�U{ǀ���!.��Bo(hfQfF:Y+J�S�xe	&A3Е`0�b[.իtj��,�O�	V|Y�Eo��{�/��`L�W��r�қ�q�_/8�J�;�W�FP�ȹ���6qL���@zC�L������i3j����?�����Vy��g[�j������\
�HC_��b���HO�;q�U�V��Pv���Cv����p�Ӭ����Q���4/��3�d����nb�#%L�]���f�y֧D|/�!f�e�2J�k�����Z*s���h4�?>�Ř      �      x�E�I�-��E���e�0�?�q${�E#V���(�Pq$�O�����?m�K��������O������R�O;��������~�w�Z��8�O���g��S�o�~�\?�R�g����o�m��S�oi?eO/�[����{�9����>o�6�[��羿�-��֏O��S��ٿ��c���k�]�?����vh���~��������n'��S~�/���[�O+���u��u���������/�_^�����Y�j�;M����;�� o��m��s��mٕѵ;E�R�1�����_�ߴ�{V�q��`�n��fr�o�oߞ������T�>�۟;���~'�Nl���?wBn�'�Qn��;�"l��{g��/����������!����6;|����`	��߱���`������~6<�;︙�����n�����2Ш��_�q ��q����y�i���|��/�s��;�yGpG|���W[��l5��_��h��>����;O����������7�����Q~o��m�~�u��~Y�Nʼú,|�\�u�~�#��Y�����D�����{3X�~���~`�����n���q�.��m1h���rɿ~�].���=w����Y���{���`RϼCZ�e������r���9��.y��)/�ŝ���r�jw��O�I���
y��r��rgl\�(<�c�|:h�n
��u�5��f���6ﺱ�ָ���]��Ta�6S\�p
���lv��4��?��V�Y��~��xk^*�3�!wǬ;ׅ~x���j�Cw��;��ԁ�d�rWn������c
����o�9�w�.��*�c�\�3T!//�ȵ�{��-Sx�lSIRLǾ�$c.�L{{���6Ԙ���e�~_���+�]��ӻq�<2�w��QFч�U����&�²��S��v��6{%�\�"`)�ʕ����]�0���q��,���}�w�?��_~��B�'����W�0�;���ـ��b��^ypקޖ�[k\��+�F"�OqN�aw���KIP.��&Y|�s�H���/��H��h�?/��J���ri�)w���K��p����4����;;�nos^fa9���Ȇ��]�y��tm�t������3��hp��A����m{�[�s������;ɷ����6z��7�ȕrf���&���leg-B�3��H�)gU�����iwC��GB��.�b��
���	�ݹn�������>!��b1�����G�x�t�Y0�wg����d�]r�6��tZ�p?Sy�W�(����������9�95!�h��ȕ������&s��0�p@���J��帻��^��'�o_Ԅ��V��}���s_����n����T����e�+R+�C=�P��$�W^��5A^p4�WQ/rd�+/��Ƭ-�[���$�����$����UY��Sᄆt�����@dȋ;����Vϟ��p�B����WY��Bޑ�tw������!y�8�V�>���Rh*=q������+-�]��3
?��A����������4E8��J�K���T��;�MA��>�^��p���sEX � �6W u�sWW���f��_@n�At���;"��;���&B����xLđtwC�Gm��ݢ+Ϫ��t	s�~����RO����AN�f���M��v��w�7Ў9���m,������%Q�<�j�����*t��w`L"- ��xD,����=nU��]l֫o�1e2z�P��c������8m�GM����#�MO���;8��������/�6d[�R�MN�KV�U��%�Dwb�e ��;V�\#4K��5�c�]��鶋��r�k=�{��[�5[��E�]�)�,BC�������v׮�`�U�GuJSl�3!�޽_Ef���eiy�k���-@"�\���4��y�:��$VFCn�"wb�ϵ2�˅�h���z���	��6bA�~Tg���Gw���wZ��ฆG.�m%|��`���U���`z]rx���	g`"���`�A;'�������!�G�f[T�%�Q���nb̐��$� }�Zhi1VT���vpO����ҷ]�����w_��K�m>��-T���x�R���au9��`���4��0�]�m�!3P�n�2Q���Amg'�Tw]�+3�7\i�M�s��l��vX�n�t�� ����Z��%����9����j<�ibϟ;�w1;�G��~9��jw����o�kPF_��q�
b����A��tN���φ�+6�/�_t���������$ʛ^1G�����Y���1��VD�m�K_h+T�c2��%��LjIC]H�����G���w��j�L������!,��V�s�^`�4x;��_�٫x:��e�J��m�Q5�m��K.�̉�B��]����@��X�ە;Nt?j��2�K��x�x%��]�W�]`�.&�������CD5���(��0�'$ƪ�6F�ϡC���Z���}D�� �ˈ���}ıT�tN,�)�.�����l��(r��`(:��RmgE̙�~qd$q� �9��wm[L����\����#��~W�N�(�/qc�*�ڻ%�; ��vʃ_� G7��N�\�K��ZvAq���3lOƎrq�n��3�vc�pO��RlS|����T3��fGY��H�<��z��E��%�>��-�E�ݜ!���N�B���C�TL������"�H�=�}�1�BLox�����;�ȯ�;��h����}\u����!�M�$_������O��H�_t�T�B�v��p,�icU�ӂ�Пrɫ4��e��p(Ȣ��<S[��Bw��;�v�����|L��~���J��1�ޥp�i�;%�Kw~����Q�p���:�}*aqy�r�`�JK8�G�����O�����rh7UH<�G���bj�`��E���)׿I�D�N:N�'�`��~���M��F�����%��������1�D��/�r�M!'��{LV��~u�z���2kk*��Yl6�Ő��}Qs���m�6�O��,�.j����khSx�y:~�{uz��1Ft��B� �U�nu����m�_��N�9y���Mu[���'�;G6��:���Êu�	ܴ�IGNv0��~i�����v�6�t���i/�~y[��S���-�E��O��Ѡ�8��iأE��A!vu+O]�����8~�����3��~	��]|n׎�N������(��U$z{�~q���צ��=���jL��h�h������C�=-����qc)Ro�[�9y��a�'��G�wLz�/9���w_��S���o"/�ꗍ�/���а��E��p
~
'��5E��Vz�xw�I#���U�������˷�3,�%�k�9P��;���e3�RW�k��Ӏ��p�v i5>�����*Ǿ���\y�AD<�V�m�Wh�ɡ�ujx`kuaԍ�V��}L�"��S�b�?Q01:�w�����_�J�{�L�v�n���-��;Q���`Q.T�q�&�5�t*abw0f��猻��4���V7�P�8���W�$0��MA=��]�G�8�;�Q�xax�"�QdE�W�tf�g��<�P+G5S⪇V��2H��q]6Z���{��vɦ.u�ra���d��ND��\q]j�m��E�y]x9c�0EK^���wX�ky���Sk_j���L �A.��AS	\u8/� mg5d�;s���@�t�-�ŝ�����[|�W��$ڠ�}հ<��9\�JK���BZ|n�՞��h5N��*
��Z�M̰�\T�v��ҥ�S��s���ߏ��J����ez�".��襸�!�Ga�ݮ���å�3K�A��z��K�q�t]�Z�;/	�R&��=�e��K�ۺ,�7�����o��-45#������-��Y���q�cz�.��w6x�+���;�[s&���_�;vwy���7,L�Dޖ�x�VC�j-"%�v��=��S����������4
̵7������b'|�*�H4��WHu�-    �^B՗b�5�1T�Qc��� ��)/"/�2wBK����M)#5�Σ������e+7��ubc��T����9*��f��p9s���?^hq�\�+R��/�������6���إ�$�O�h\�!~7���͹T�G|'c�F���t��k�_ߜ���m��t}7�HG\m4:r�W}{����ѿ�Mq�LC�)��v?UY��Zlx��!���W��!ۀ��ƍ5�m|{��C�������8���?Kë������څ���-���N|��� ܶ_4�H>ё�G�l���,h@�����n��c�+�����~s^�nb�]y�ip��#��d���oz�l�N��Z��Ҋ7�YQd���"���I�y�0�}a��#7¢�{c#Z�[a����S���qd�Rx��]��&]�Y`d��v��F�-�2m����+*��rM�P���n[Թ��]4�E��h�lt�so��6Fl$���9�yQ=6�&ɥx�3�z9��?ci�lvG�}}�{�lv���%��.K����5�L�s��g��<����c���%�~.i��M�08�i�� -Xޥ�n�CdDq|N�>���!�%O�˿��ȿ}9�p���)U������X�<;��y`�b �$p�!�Oy
����R(�#��;����3�F��U"�;c������%�xj��N��{�J��X�a"���GH�m�Ȉ���!zr�����w���$���m���ꒌ�t�a��5�R(d�G�����a�R#���:�$$��\TEf[$ޏ3>��|�/N�����Jr[�\)vpv�m|' F��BXW�����\��]�h��$���{Q݆�12pI���?�#[n{�v�_�"�#(U+���ԫ~[��D�� 0��^�jd0[Wdl�z�2fܟlF�	pthy�|�R�&U��(�����3h��zQq�pڂk��;J�/o��b����1�&�����Ÿ�?��3�~{����;��G�%�^;:���P�AMI��_T}H�bhߕ��}lyɂZ&u���34b��KvO� ��!�Y�B�ٺ˱�k�[�Ke�ĵ�X�tU�^!s�_�	#Cv���f$���r~��k� i����!�>�ܡ��>�#��U��-�T:�i�,.=���(ā�~���"	l���{�Ճ�ť�aI_֪�2G�*�ߐ]M	h�'ӓ��SxH����t�s^����$��VC-dH�@s� �>����y���Р�23�=a� ��`(���	�+ˇg-�#`�@���9����K����ׇ����p�%��ޠ���>�/����/��Ѹ��~
�l��b�����������dZB��Q�5KÔ�l�$N���>���V7HbȗF�����wɩ/o/\-����	��[���~�y��FZ���T96�G61h�d6"� ���������/`/[.��j�0q�t�,/ ���_T�P^��
1?�-r���6���Ȣ�"�.}������!$01Gt�i�H������H��;#�if7,Mr�����5�#>�"�tG����x'~�[Um��%mَ�$0*��.u-�X��D,�I��q���5@J��9&u��b�?�I��U����K�VH��@t�����Ć9p��%a�GG/�����!&���0E�U#es(ȥ�N0-�茬 �b�Z���9�^+l��
�Q��q�uA�C��;�m�PO�)��n�*}��m�}> F��I��i.NA���
��85���a��&&��w�m�gpM��.\yt^�f����Gg�5�t�Z.�Q�j��l�/�OO0ИnLI�tQN2$}�+�@Ri/h�#^�U��ϣ߹�wrσU�|{,��4^�Iee%�洼o8��}�ж�	�E�eSA?�f%`n�����g��(���eo�L�F��¥5��"*��u�C��D���LX�/aUԓ����KGyb�VU5�^T|���@��r~v��*��1�xL�B͟������f��m�d S%��&�'9K��#�g�U�����@�0�(ȪU���E�����Kd�Ľ�p���T�Ph�Y	�UQ0K1��NW�K&���ʌ,���?��CS�����	�7!���pՈ~� ��v�����0�!��$&H�:tB3�h>������?�̚���N_i�����حD����Uy+���BVQ�� ���It���F��wg0l0j�]8��+zRQ�׊Zew���+�Ҳ��`��O$	�Dt����eU���W ������F�q���*fS���+`4��;�@��`����􋣵T��=�غ=pt�T���DK�-J+M}�� �U��	7us��GHc�2D[G��CG�i�����c�[���c���2�Ha��W�fx�AU:I=�
/A��F(M�F<2�H����'�/�&z��xq���*�u o	ڙ͈-/�C�������-͔��Z���+G����nӲZ�+8x��˫�H7�4~o�&<�.h����$��/b�BG��ͬ.Æ-ߩ���/(��X C>pW;#�t�0.�z>W����`t�Ih��ޤ���T��@gG>�~�jҩI��o�fWX}��w�a���f�E��9^I� (�i�����z���;2#��[@�-����<@`���ٳҷ�$�F���-(h�k��0�����8!�V�_��2n���2�gO��������U��+_�pS ?�VF�����>x�Rl�ej`B�ΛF`�̯���5Q�'������;�۳f��?B�E੉��S�IY��{}�1���*ρ�d[��ǳYD���}���^��h(/�iݛ��y�Q���/�V�X,8J�]��5��a����z	�;͡"�l��
2׉Y!�`b�=���d*�>+|i�G���u<ICu���p�߱��`"�B	JNs\��?����L)-�gē��/�v'q*՗�5T��a�QۓzQD�9��G`����Yj
�wvF��
j��X/O.����lQ醯"p�޲M"�m��T$�G�Ӈ+��5���	�qK�,O�9'3�L��>4:��pw�Z��ݣ�M^S�w�Z 6r��2`��E�3�[�-���OM<n��"���"ڱ�� �e�`G�M�!�\PK|�sl�$����@�b�B5�ȅ.У��_�ɉ3.p�֕�A2�������F�٦���ឮ��\�ltGEߓ���(��M��kc���Fjd>;�1�g*	܂.A+A�SE��E����l�A<�,�Q�<G��Z�����?HB*���}���X�����X� w��p�%U����I��9���F{���Lti0b��=/ٞI1���=C|O��Ez�.�,�^�������'��0��ӺE��7+B�)����7�x@Z�H�r3��)�Y[|�+� Y��ys��Y��jՇj����=�$@ja�EToO��g���^�Gs��~z��j�C�:�|��/�6��cz{|8َy'g)2E������%�H9��mY.fB�t>�����t�"���T���e�k���!hnF�(��c(������r�k/작�nI�C=yђB�]��}��&y�Y �M �zH�.N�+<�r�5Ժ�Ƕ�a�a²"N��A$Q�)�7PIh���aNQte��+����r8�1��Sٵf�7Řt5�-"���|=�.�'z���j��Q���U���KD(B�����t�������z���N��1|�tka��x��Z�2�o�#5T�j
��z�l:��{��fw �ѩ���t����r^7�WEG�i�6�<�nz�q1b�9�1p�M�l�iY�d��%@]M���E	ą�1��O�HI�(��|������?�*��g���bp-�=�s
s��ƣ�{����f�9b��4���[W�9�H����T�g2M�"�A���>�]NY��R9��'�xm�-��K���
	!6K    ��MF;�A�x��K~� #f5Yp��,��
��,N�� K<1 M�!wO�}H�p� =
�k���&>|�+��+��^_ь)��b�2�)��M��F�$���-�"b5���WZ|h>ﱦiF�u����)�������^K-w�^9�/>i�$��ų�)� M�CPw2d�����	��)�$��Ɇ3���q������q<MnL䎐[��n���o���V�3�1! �X�JdH3^����/5��]��������TA
o�>�5ˈ;`E��=>㵒RN�����-�m�&�?n-������|���y�x�̆t�OBAN��g>�O9@��\+-*x�P�?�H�K�B�	`��W��K����x��8���	�^B{��`:e�I=J0�(����gt`�Iw��Ė���0�з�,��,�R$�Y[�yˁ�Ȑ ����!:Y^�n�V���d� ����t�ΐːϰ��4-�AP��(�˲�7��)h#4mV�Օ�2mJV��y�wZܼ��,�8� +���@�	���t�d��W�f��R�[
x�zBeY�	�
�����O�Q��Tt$8��Ҟb�r0��<��a͵�n���7x3� 2Y:�D+�`�~���W'v ��2�g�2.V2i�P�z����O�M�o���gY�B�k�L$Y��W��	1>��i.o�T��2��3��b�gz��U�)���jѼ��hּc��X��W������~>g�aJ}�9�6?'	�f,G'[WO"�`����Д��!��o�L����`�m-���,�m�R��Ob�@���yOXrFwv�+���w�]w��/>����s�y �qN![@:��?�:��H@���#�`����0@&�s�3�Μ(,�6��-�� ���@+t�r-��z�H�gx����+�ыc�4�\�=^�>c�0�`�����/��~JR���3��ś��얒bp��q�S�d��f��Z���3<�=x@o9)@D)$U �|v���;���> �Nݞ��}����U,������}^&`���L0���g��m)������S�H�G�t�>�Wr��\l� �]��΁��{�2S�.]�T��̸���PX��iD§K���`帄D��Z>�j��o��&�P��u��J��I����z���T��.�E��oe����Җ+�fTM=0~�_�.fN6�	�Ҹ(�� ��i����~�c4�&1Ծ��M��]�Kc��"k��ӯ�^=���0�"v������}�iN�i 5��Y�I�+�j�uM9��:ѱcտ�-P���ǒTN/8j�\�c�/� ��Q u��󘨕�r@�u<Pl��(	 S���ʎ�m���L���sL^h�.ON�#Z��1cKg-��g���?�j���vG��~�"K��"OP��o2��i)&�2�|���� ���	9�JV�#��;�H�8W�� �W﷬ֽ|��qV�1�Vj�́��q%��n�I)�l�8�DY�8m�Y[����} �w���3>�3�_"Yi��8
��
غ�Z}��gз����ԺK���W<X ��������Ժ�3v��D��+kxkq'z��H
:�uV��=+*�Ӥ7:(����Ub"�`���O47 ؠ����T0ةd������Fׅe��u=���C5 v�����8rh�G/#{�����ORv��IE!�ٱl��ɱJM��Τ:����'�hF,	�KռqZ��(��I_��
([F��BPptU��M�#e� f@W�e�*���T�^v� ��U���K���fP�٪`�EP�)բ�.�P �=R(
��W�������ۧu�^#I�^_9V�e���˿�p� ���/ˣ���_Y|%���@iꧢ|��V�w�/�K�@�"�@�ZyB��̮)}P?�b�L���Yآ�@���"H�~-8����u#}��P�hv�o�{�U��f%�nI���5u�r�yk��8�-�Rg�����_��ϓ�Bw��1����y�LU��Q?#�+��j�2��^���p��/�c���UϘ>�_}��B7�s�,�6�i�Aw��v,�!=�^ze�Ұ^]��_�G
:��R�g'��϶��5�N��{&�JzN���)XAg�?�
t��73/;��V�,��|�7��O43��#�gpY7��Ά���i�A�T�wN�����؁.���G�F��fR��ȁԆ�KaQ���Q�m����ڳB"XS����1+ѕ#���P��"�Qp6��>�}#�a�W-S$��^E�*���b��Z����դ��2U-�g�8t���Sf����$kt�e��[4V�3 :ۊe��GSc-:g5b��l3䡛�|�U��P٨��_��=��5yS���*W�*���j�S�W�>�L5��Вr@��g�8�P�����S��r[���I�A-q`[�4�z����6�5�H�ft5o�t7F��Ȅ�Z,g�^�T��L_�V
3`�����~	J�����e�F�l�%��rD��� H�%u��:����#����S�B=�h#�X�X*���>L�2q���b��C�[L�7��aN��Q!�3)O^1�&���̮�T3tT���-&�������3�V�uD�N�\���@�E����tq8�H�t�l"��h4��]�#�S�Ӷ��,��`4GNs�;���LۖeQC:�)N�$�Ta�eF�#[]�J_�q�mf���'��w[
��$U3�*xd,�VK���W�o!���SS�w�yK�]p����U\��	[-�gZz�Mr,_W�e��
�����l㿐M-�B^'e_e׿��)�W}e�"Xm<5����T�����L��e�j���~U�wK�k-�Si�<#�i�f3Ko	u�EA������YT�I�E6gK9R~���(F,+����>v�x��2�౫8�
 !�X�F����3�h�#�c[!�iN��F5��
�O���aa��W��PZ�H2SY��ɥ���MZ�����M�vb,�u�h#5�\S�3�5�	�6�<�*V��f��7�d�7}��Ra�j���ؖS������Z����D2�W���3o
v�D�r`��N�x%��GM^K���#{�CmU/e�m�P:�L�d��-�a�ȨG=儭B�Á�lV�n���]�μ�)rR�Y�#�7ٳ�"�]Ed�A���<&;�G�ժ�-_�9�d��Ѝ]_��g�EC����%֜���=	�ȥUX�����I��n6R���o�(����a��?Y�u�GrLӔ���]�ʁ��0@'Y�i�pL��N�XkȘ��u���5�|��fm�/�%�UM�G�:��+d��hVV�|Z�e���_�+|$w���L\�tM���DX�|�:2�Q���B�㰭-�k�At"r���|���W��� -�B�E�X8E�/���	Y����ӶA�ڬ��!��W�CpFo����4!��h�9�^������iȂ�N
R�=��^���dXF���k�X��[���8o�pq�T��&�Ԗ�5�Qd�g�&��F�ѲX\i�Fs�$�ԛg+S��}Y�}�Xz����)����@�H!	�jb�8�M��/�@o�`������4��Ə���V�����-��љV�c�g)��.���\�^�j�"W��f<-g����% �u�ʢ3 �Kd�7:��O zn�w���Տ�����$�EGY�����_@N殱��q�ԖJ�Զ�N�E�#cO/\�������>|Q9��?�f��]'���b���O�d#��
D+�=N�B�y�	4��\���;��R���y��^�����೛o ՛E8 ,��Խ6s2�D�q-AM�%d���[�)��ܡHS��'���(Nš���U ����d�\�����hB�S1���(o0���O���ȟ�k�T��'���蹉�ϚF�����)t}T�ro���fr-�e�Z%��X�f|�C��d��eK��]$�z�6�!?�`w!�§V�x�?#ʿ���j�-�.�%    �_�n��XE��yR5z�o�eop�<�Z�[���΅��)7Wv)�QEdϷ�)�,���ҿ�-�_���UtW�+�t����A��V;����;rP��)����=�ʌ�n��������u�I�\����W��y���5��}�#dRS9w7 ��9S;��O,
��{��p���7�Ļh�����~3����a�L�=b�X^9:���O<�G�V�,Y�_�b��b�
���j1���f*�-,${�}�jҏ�L/I�#^z����<�~�RE��VZ.�Բ�*�w"�dT]d���d����4�4�;��}�zdW�A'oD!�Ϋ���%L�#��0�?�)aQ'Jp읱sL��N0m4gᢘ�^~3��&�	׻��;s�?����eC��E��x�o=i�̱��sf�Z��x��s<La%-�X�UhFt2�>��SЧ��,�6���S?��T*��0s,*�bV����ﯺ�ϻuL��HEsz>_��>9�[0q�{jp0ٺ��3E�GL1�O��+:�L%�s۠e���(�볒��\)���p��N�e\-w�����	�r�P�����)T�"���4������R���Ѝc�(8BO����l��$1&�G��5�(���W^�>u�^�����F�c�Z���k�h��O|�b��S�%�P���,X���ئfgH-�@l%�,9E�$N��+�����D*Hl+�T�7��|�@:`�����X�:uaG��/��D[x�
D�%7��>��-WSv6@l1⾓����=d3TSq����_Aa�M��h�����;A=���N+$�\�����*���=Y,ֻ�JwE2f�n���l�Z�V��.:M8����$��~���HN+�bB
�f3M%Rt�,zW��+H_9�f '�"�h�>xCM�W��Iv7��3�\a#����1D�Tq�5�]Pؖp�'�E�Z
k�%�# �E���$�M�[�,/S�\�=�h7񼸌��2}�/�o��E��*��}^;K-{9��?�9rC����d�x�Z�B8?d�̀����4��1��Q�&9����Z8���uxȣ/Ŵ����=��+�F���rdɥi�~r��T���8�����.�r�{�V��x��w�y7z!��W���6��@��b�nB�1���%�L�z��0���T fiDbq	�W��[�Jn���1Vw�\�m*��n��e�U��(�HE�
��=K�QL�U���\UǮ]������ϪQ[D8Hl� �9��H����sCg�V�y]#`�B��^eb�'$l��`�+Xl���0A�^Ά�ɷ,��z�jzC�e��3���/�S�B�MǮ"�J��~�I��D�dwq����{d*X�敗�)ƙk�%q�̫��q�����R$�ɲ�W<~������ݫ?��?�3�j�0��KaL^����]��U�c�gE���J�*�����t~�L*�+�loA�U�}gE��N"I��t����_Nȥ��OE<vo�nN�*ڧ��/y��a���=�౧E]��Uͮ�S�;�rG2��8Z���MȖ!���	��H�gߙ�d�W��]|�� ����\s���,%5F��֛����w�_W�qx��z�! ّ�౽x��c�=�p����n/z`�����H�dK����0+�~�
���'ix���z\?h�' �KJW �v��[
�U�n���,vyw_�f�su��M0��Ԑh����F�?�V�K������$	����6��+H��?���AB��L���k��P �^%PEdQLAd��Ax�Q́mh-J���icQjsA�{.Agt-QDG�^����-�yc��	}?�����FHvJ�@פ�B�$��z�&l��򛿜nL�����!ң����% ${�R��<�ֶ��-�����J�y�eE�p���Ad�ߦ�-�����ؗ��or�,��R��nC��#Zg�)�����>��U__�i��!�Λ\/��JP�V��e���^��h䕖l>�"Ħ�2Ε+���m����h뻅�5Ѧ��m�a}bx��6ZG/1#rqv�;��#1�~�{ߟzw���a������w�4y���t�d4�]a!e��Щi�G��A�9ׁd�g���;�Õ}�Y�`�1 Y�cH6�y����N��L�qO���ɚ�/�"^Ηk�9Ee'�u�wm���;����ַ̭�߻津(d��Z�^���-���"ؽ²��Q�e�$=U�\����3GN�D6X�:�P��째�C=w�֔��՚\w�UݛY�_�nM�랾Y�:1-����K �ͽ�[�5|c�"�E�e�4��O����P|U0�\��%��j����m�$覼�բ̶׏��ݟ/��S������%B{澃zF�zv��`�îq{���o�wF<?t�c �a��F@���[{z�/ m#?��+�|y\�I�˙�.sn������[��k=��z���\6�����[ C`�S����A��xe϶�W��9*2G R,g �0��P8�k��	ԋ�~~�����|9�`��c�Y,{�rt%%�y�1�X(��n��g�R�ܸ���E-n��BX4��@�h�z<��6�{�'��wF.@`	(1�%~!L�J)���2]єr���b��Ҷ�����Z����ĵ�+�nA���Cz�������jAS�1� i������	Rn_���%�b��#{��>r���ng�/�k团�)o�,�}r��(���g�ږ<�d��{�]��_:ɋV�W�
��7:���������,)_ܾwK�?����i��^����9|I5m��TN���||rm��/���+"�s��94o8����]�v�|�8��S@�WQ�翂�9�}|�p��g���vV����ƻ䌏�(����zx��qöO'�H���ˌ�\���Y_z+ r���|~�;P�u�{��m�
����3��,o���3:��ۧh��&:��YU��Js��I��2T����:�G;3�THퟸq�l�-\��%�K�vn�ul��w�v�P���9�"��~���gn�x�z��ń57��ܯ�/O.���O�]�.�U��dJ�"�H����6:��3o��{=xS�%�N�c�,��W�w�[���]�R+Z�>O���nW�{���6:�������r^�ʗJ<��e{Y;a�����������}<>J��Mjг�tb2��vJ�5��@��=Yy�z�M:Z����	�7�O=A�i�^�+�v��V��˖� Kn�b�-��È �u���yv�
�?�hm.nE�h��w�R�s����#d�bi�^+.6�����/ͱ�����&8�֬F[}�Ӄ��0,��m� g�c��f[������(�G�L��?�d"����U�@f[ۑ���Jğ�"}���X����hK��)�E_f���޼�g����h��3�w����5�Ԥ��v�����[�f(il�P^#d��O�8����t4�d�V�2{����	���AM�p��
]�(�*H�>���ymڦ��޲�3L�S�e���I[K6�ʑ":{d�3�e.N.A�"7,��c��г��䛖�����͆=8T��FVȒ{"�Ax��V�~�Jpv ^Mtv��|ٗҹ`v�N*Բ\(N^hY�|��Z\$#��\�n�&��>RǊ/����-őS���f7�����0���܀ת� u�7������W�ZX/���uvL\C_ƌi��.�`�Zm�
�5Ͷ�� .�g����N�����Ր�I���u3k�ӂ�8">,��{�~4���yQ-�l�/�b�(��C���q`ß��[����y� �g�����<��{:�pV���ȝ��wF�LCN�
S�D�1��KHZ}����b��EȟzA��4z[�em ���l ��2�˩�OWL��	~��fD�������m�D��c�f�~j�-s��+��f��o��32�]vΣ�מ\JCme�_�_��64�WI���xUܭ;Wu��Ա�N�wd����Zmf'n�N�8���ڒ�Z��V�2$�aD��=_��0�k	�.��V�>�؍X����9��E?x�#�llF� g  Rr�������*5��D�¡����U���"�K+Ike�X��G04�G���Yi,���0���Z4>�ɐ;W��Ó�m�C��
��\�E�'g3'�	�>F��uN�i�Yݽ�z�DI�rInn��Z����"�s�X�&ϣ��͎f]�$ٴf�:�h���ES���Ԍ>Ւ�"�f��]g�'f��T��5���Ӭ������w�'�x�l4p"��=��9������O���qp��N�?�j�>�k�m#
6U��4�G���N4�?r�oZ?V�r^oTk3�:uh'�xn�d7��[6�vb����Z�����.�&\�{-�`��f}��ٳ���ʬ\�I�\�V�gz�8*֥}B��A�!����@A�n%c��XZ����ٚ��g)� �t-^۹~/�V�OH]�
8���pgG�h!�`�-��c
+f���x�fn�L�ˆkҳ1-˥�aQ��ֽ\#��lks~�q"�P?z�{[�نH �lX3�������>���w5����7+e��E�u�m�զe�� ��+)9I����������k�o5���P�3:���e�ñ�؂��73R� mݺKz��e��7�5E��<��5����{MpvW��V;�I*_�`t=��+��j?rse4�i_��TɎ`�=ͮ����z���
]it&����%�4�+� =�\?�m�W��1ك��Ժ��#S+��w��!#��h5�%7�OBu�VK����D�$ɉJz��U]ff|���ʺ�D@{�o�L���yeۨE�y�������wtD�>[c�	q�FV�l���A5�բ�s`V�nbm��7F�cX3�����-����S��8U�":���E�Ǘm�S�W�a�?�8��L����k �-
�r��l��ek�2P�5��P���g�صg/������.6g�ܻq�X��C:s�d�Xz ����,]���#�@�x���C΂��k��mϚktK4�а&����%�16>J�<CN	��<�߼q����Qr�8vK��&�,e��0���rdl��B�Ϳ��W�������}��!��C����$��I��2�c�U�aٵ薀f[�9�w|U�E+g�ػ�w����H��E�A����V���I��-��%�MTv�mx�l�|T���H��=���qTU�&�X�Ju|V �_}�f��ܸ�,�}.V�."Q���'e���F^�l�h*���	c��&0;`��oQU��
;�Q 2�f�"*V�Ul�Q0����0�	�򟖴������g���(0;mX�f������򋬛��3�+֯=�G�>h�J�������w�^7Q��ci����Nt���d�nr-��Y�=�9uE�
s�-乙��zZ�
ٹ7�YU���&ӻ�[����qw3,۰���cq�YP���0��4>��rL���~N��2֘�"��7[d��B{0 �������
�.'�O���yB�b���f�3#��e�Β,�,)wiǮH�������
V0���ۚ�m��Y8S+bZ�Y ;W�5d-��$��� V|?�g�@���y.D`�����{�l�t�Ƕ���E��`�L$���kl(�q�B+��xpz��jqROke�Y�4[�>�V�wo�q°ԞX�Ȝ�@M0^�5������}�K���k��S�;��:���{�4^4��Nu#P2��H�{e�$9	S"�E%��l3�gH�G5���x�-L���-&~;�%�?�w���5^-�:d�Fɕo��ҼWG�S��y��cX0�I�mj��i�<��h�KȸW�7��k־������X6ɲ�V�z����-��^b��i�7&��c���J3����P����6�xI ��(�0�s����vO�j>zr���O��d�����`�w�u68�h? M���I:)9D���������_t	��#�r��^3��	Ϟ�u���񠳽�eA-I&	t6�Q^��Hp|pv^x���M��B���&����s�zeH��s1wV}�'�|r�i?޲�@O��;���	��%u��2�g[-�VN��f��NS��9���kqr�F��;!����AK�-�2 ��T@_Z�]0��fR��s�����-��q`,��.�W�D,qº�KahJ%n���Cr�����i"����Eӣ�S�@h��5��U��g�T�o�K*�6��%�����NW�l���^����f��HV�~�w�$�s��*�� ��d�bvB[����l��rr�/�����ݟ���Q�� t�x�ڥ]���Xӵ�r��J[��2h���ݹ����Z�my�Q���D.Do �-7�,�Vv��m�nã������0L�v��3qT��kd�Z{D�$���Mp�bz�������y6��3ն_&�m|�ΦEۊ#uN��%1�ٖ�h`�q'�E��o�K^g��w�o�߃@����B��H�]^�h������㞅�֮�����wڊ@�����������
h�|��5��l��r���3��l�;�C��-�2�y�������1�e+^=�#l���c3��m+�'B:ےX�>��>G��Z�u��d��l�ܟ��1�\��v��>o�͘x�H�3 m�a���������6 ��зm��T��-G�55�6���%��֛9k�'<;�e��u��=S�m����-D�n�Ύ'xv.n{�����F3��4���otvMi���.���<{<x��u��(rW|v�([R���^9նY.5�'[䉔�����h$:['=P���qт͎���:	l�7����{��ݹVs��$�b�.��--v�;<"��g[��w��^l!�9������g�N�&<;���l/;�}���E�h�C��j��N|vZ��6�r�S̩*@;�*���U�1T||���  m�S�EC�xA�
ұ,dҲ�;/u�9�e�ls�p6Jl�w�u����s|��Io����N��f� g{�.��,����F�����RH�T����@��Y�g��lgǭz�Տ.GKM �`-���@g�Lڃ��D�K����N���� ������y�b�x?���wn�~6b������q�'7���V�s�����j�ԋ��,�Q�����e�$=7a�5�A"��iDe���ȍ��h&�w,��͗MTv���R�G��g�6��-���}�ML��z�a���� ʶ�����&(;x�*{������45j��L�F27Ҩx*���umY�HxP�+���M0U~��h9�FMr��D�\}o���t������
P��~TE`�^�E�� 
.���z�=���zvY���m���w�>��It�:lF���_�����������o      u   �  x�]Vˎ7<K_1�(���vHb���)����n#�=F�L��S�yx���(�XU$�7����~B�ZIk�F-Y�%���v����=KNB�Û�iBѪ�%���\û�<����Bx�v������p�j��v����kf�o�R����q7�{��E*�'z���i!D�%������i��y�q�|��N����z��8R�	��T=+%u�D�<+Qn8�Y��H%|�-��ӰBB��k�ĸ���2�3m�jf1q���V���i;̏x��n��Z�x�{b\�>D��S��NW�t4I��w4���i�jN����zז.Z�e�<̡f��D�Z��oJi���-�D-�|��E���w�P�m�����0�}�&�;$�F|z��1��MRi8|����N���e���k�uÿ`��B=Pem^g�=1�o�,���@�*Z�c��~<<��#��*��[N�zI
�d���-���S6|��{��~w˓��Zm�?pUZĳ����a3ͭ��d=S�yx(�ܻ�J�\Ӽ���,IР�p���@[� ��b�/P��5�ΩJ�p_�� �id	w_��q�+�[�'�Q*kxN����n�����-�����o��&����N���a�F�"ݲˊ�zC�_@-�7p�Oj���jy�Úa�*����G�h	���8hB)�X��q9���޹������v��o{ǝ+@�:�¥��X/ U�o��$�t�R֢ځO�
B�"�{����"TD�KGMaC������kJ�~�NYc��։�ԥ���FqwkLN_�R�����vX�{�RA&��b�W�V�[��y�^�Pk��v�-(�e�����5�09�
�����H��z���r�p��?�L�N�gh�P`2���yp���(]�ʅ�SV#(QO�H�ub`)��M�ˀ1ȡ�?[*x���ǿǗ��qy
��-����I���k��:�Z*8��@!�8�Tx�L4����z�oB佷��`�I��L�#���s��f��X-ޯ�2\ogDT��H���J���4.N�"psM�T)b��M�9��=k�ME�f\�:��%��K	f�R1�^	��0$	��ATn�Bk���=��ä������0H����N0\#rG�`m��0�e#�m)PQ��hWr0��
W�k�x�/k#�p�GL������=�h?E�s(xnƮ���a-����f�*�F�>����=o~�-�;BGC���N"	���S�8Z�'���ך���+���&'��4��%`EBq����ү� �/��',�����b�@77���~������H���~x8��3�b����#��N�G����gؗ	�Bb�+z�=��>�����qU|��Ŭc�E �0H_	����bl��%�Kv]a��K�\����O��a@���p��3���x
Rw��dT��?R��_8�o�         �
  x�MX�r۸\�_��]��7��˓X�GN&7S��DXB�"���������R΂ x�}�H�(��6C۷b�6���o!�2���U$�H$���T#~Z��+>-���*ʃXęx6ͶVƉ��k�?�D��U(qC���׵i;��-������_�HŃun�μ��⑯���*��L��^��N<�O7���y<Nx;�Bb�6F��ۃv���<��2	
��������M����~~�A����6�I7���x���2d(�B|>5��M��N|O�)ӓR$�x����^=]���Dtf�Ȉ%^�]���+���q��`��E����^����씫��Q'_	~	����3�suԪb����d+d*�18�,�N'bV#���D��Dc�Xm�p�q�W �\$���*�R]�ڷ�0�E˦���)�~4pq���+�Q�a���7��З��[׈���W� ��5�sf�����;v)�z��?�k��?���#tR���"�&b���x2[��:FJl\�2�b�lm7�n��=�Z\Ea%>V�٠$w��w|?������jЭX�c��O=�A&�X��ش��<G|�>ϜgAq�sj�G&��r��I
 �W4'@Ҏ]�i��@�k��j8a�A����C���~����8B�b)P/�h�F�b	7ȓ�wE�Y�ע+�G��x.Wľ��R�jt�Ӎ�+s.	�	`-TU!&t<�3Ǎ��&�� e����M�וm��CF��X�m�޴����6�ٍ�ʼ �\������wk_5�z��
\����-�~k��x��`㒇�>Beiu
ཛ���=I(�
,?�ZOJV���A"���:��s�l76{l�ׂ$"���GKVj0��	�4	'�E=TG�t=UX�;P�$!d!լ�A�QD��$����rƊ���UӌU+�,�-O�P�l�B��I�k."�w�w�+���E+ci)���us����J��0HJ���6��{Ӕ��@��X׊�z���Ow��h�P���rp@S��|�y
pH$A�e���m�Q���s�Q��@D� M�r�߽�z��S�)!�V�u`첟�rBxNUHS*�7���RM�ѯN�����ca[��g,^ByE.��W�}Gw{SOcó�--�mϝ�j�@�����@ "F�#�1��ͥ:�2�'���3��2{;��M`�$�tgj�8��@��8���0�"^�ږ�T�(rAI���	:L��Y
40CMŏ�uGmp�פ�(���x�_^(�z�̏
D��<N�82 �L���x��[�Br��Z�f�Q2A>��� ���=�ruJJ�Af1�� �B�p�DK�L�  D��(o��\�QL�qL�E=��A��D�-E�G,�um�+�Tk쇜�>� bC�i����� O�_�[���j�f������pTdG+�i�\;�\N|�3r�x�Z<(w����˞yk���0nc9�[��|;�f�O,U��P��'oX�\K"�������v��<Rrb����,
g��[�Y��� �/N?X���hn\����so:�R��N�� D�Tqo�Ph��zy���=��H8hn��8[�����E����y�o6z*g���EF״���}�N������~�2Aoh���_n MX�.�|~6'�5����ǆ	��7 )�Q|;�"(Co�zX��8�=��4j[)�R/
5�L�ҝ'��+���Ps��;��t*uɖ�1S��a���>t^cAb�6�S&T7�LS��:m����+G�z�����p����(�*(3���nᎠ @�5� ��{�.m�� �\&��6�	�e��1�^9wq
��8ݒ�.Ƞ,�L|A	���G+��aHA���oz(a}���8�(.�"��װ�ڟ�wH;#�m^��}ѐ��kJo��ػ�a���U�h��a©}��AA�G7��j�j�˅�4����@�;�-�w�l�D�mk8�vf-��;P͈#���&8��I�𑡟�����3�Y�|:2Ɖ�����������ǲI�툅V
9�b�o��������3[��=0�s�D���{U��4p���\�t�<�7��7�w��.��"1��׻�b��,T��ǇG�#�^���~;�y\�)�w�Ei�&��r��xUT�[�ki���h/sF��A�}m�q�Ͻ��y)��2�	l�!����BI�[�Ǖ���+%�Z�|��٦;9����%�B���UУ��¼�c��Vܮ3S�r��c�X�g�C=�U[� '�_�P�=0��4������8+~83��p��,�4����[6g����~N�}��?a����̨�{-f���;�����s�E��h�=\(Y�F�g��4�r\��t�jK�5�T�1ZlZ�wԢVR��n�'��)�fE��j����y�7�-@�.s�J}L>h8�V\X(�|�3-Km[mnΫ��p�����������!��]���6�c����!�����'�C��[���J����km)�m�|��$�����kq��/�� ��=����q=.b2�+����\��"������͞0q���q5�I3P�Y!׾7�+��Ӵs�R2��}��5�j�d����o�����LJ[w��5~K9B����o�$
3���t-Yezồw#W�xq�t��z�{���I��4z���A���
cBh�?҉��N;5kз��xP�݅OȦ=��o��M      }   x  x�uU�n1�W_�/ćV�6m� I��oq�a�C��}(�:��Yl1 �3C
�/��_^>�\N�Pcj1nP'�	�}<�����+&7���b��ZZ*��0w�l���iH+��80���+&5.�')�}>���]/�q��
e�M��+�pGʫ�=�U���'@t�E�� �Z p�� V�TU@�z:�5�Rl
�?huH����ԑ?5JVI8��}�R�a߾�������d0cUZ�=9���|��*&5��Vr�Y�7�k#�0�
?�A�s�'�)��螫��~�gW�mVK�V�,[���xtV!O�嫱����3���U�aD��'F���{���q�XK��J�`�Q(C����'�xI�4y�z��XS
`��Oٖ��G-g���c�w���3[�^����lm�;P�u�e�,y��sC5<=��y�$����T�ح�����0v�rcr�����5�mb��qK��U|`ǃ��4JW4�.I5q�N1V��e�U��I�=Q��t�kC2�:Z'LN��5>C��d����K1@�4�=:cr^ ��F1y��+{[���ʧ��jOr�{��;�no�'y�ϳ�[Z57�y�e�{ٗ��}��!���]�      �      x�|�k�#��4�۞�#Jwigg���DB���oĎ��n-�JI���؟Z?�)���_)������������o���ђ�����l��������5�u��`d�o�����ڿ���3��+�z��ߪ(�;?�'�|{}~���a?4�����+����۔G*���_����?��Q��a�ښ����ot��e��_���'��ʑ?|��O�}��}�v�؃W�J�&�q��8��e�W{gyˣ���W��N�}�Vf�ִ/x��-�sG�����RaR�����2W����ٟ���W|WÀ�]�����Zy�VlH����We}&���,鈭o�O��gO��O��-�sb��ڟq��sx�m��Z|����'v��ny�._Vv��I��}zz|��w,�����q���e����?x�n�"�����{���OYS�^���v=4_�oקq�=�9l���V��ޡw!���e�x���X�S}�)��s8�	�g����݉��Y����p_�<� �����.���1��;���N�}��nY8���P���O�l��|�%�8��u����:M��رw�'��ާ)�&�i��1�$����N���q�r����`�4r�����2bBJ�3!�����>�bN�-zD�w�T����1�4.Z�n�����v�N�
�?�8����S����b�v�!�}�;3w�x����:��:�rF�u~t��A�[���q_�����߶<|�b�ä{"\���o��<O�X�?�k����]�Y��6��{��&[�{���91��Fܟ�2E�[�������%��S�8/b���4���'�M���m#���;�>K���O�<�ֻkp��f�G,���j���k����e�y�O�	�r��os{P���ory6|ۤ=���8l�<�~�ˉl:����&~p�U)�'Y�c�[/����\kq���b�a�麟�S���qw�}�������݅�����LԘ`�M&� �U���J6[I96w+:#_E��Y��;a���C����S��w�N�EU{v^��KR�nΓ�<�������r���N�	�M�|��j��iu�TF)�ػ�����\����������e���H3*#�%-~��~�����v�q[6n �a�u���o�~�	o��=E��;7��������vu��ݎ����o �_�Z�w��w�7E�V�����7�}����7^��S����W53�_vG���������fUO��^S/F�f�շ���ǉ��o�	3�D=�Z���z��T�+/~�d����j�y7��^4Ŧ��	x�y��߳ܚy��E1�*�Y��.�y��k����R��~���7����I�w_�tw�M?�e��w�Pf�%��y��!���,t��K��}�{"�9�Z���O�Oq���{��3�f���N�����c�
ñ�Z�%�w����FL�A��kuY��)٣5��=Q̼� O�[�]w�>��`1o����9�?�o���]�2�4'����꣧k���(W�W|���O�l�:,�]�!.��뎀�^�g����f�Pm����Nv>��y�������Ӊn�������׶=��*_���1=3���O��¸������\��:�j��7��3c[���Pt�������<���m�[W��rɘ�@h|�.���<k`���#�A������,<1i�Hʣy�ųn6�V���̦�G����Kr�=Ա����mN��ǳ�C��"���`���M���ޝY�_��w O��-W����qz�3P
�Ѣ����;J@�{���{��̓o��%�c(;.V&��f.=��;T"����Rc�r�,?\FsǓ��`�L��5�vd7Ӝa����Aw�q$`4[d�k}ע�2�����6*��mp�*.��X�m�!��o�F�ȿL3
/� �K�ꯀ
�rfX��s���k���)tm�u'$�x7���rN���{k�C�Dm�ۛ�����;Q��*% *ǋ�vxq�r��nl>r�o�M.PA�2�"�𖋢*w�]��z�-�����+��5�����{U��,��te��������;v�n�Jx�^S����&�t9�Tt�Y쁛�] m�%7l@�_��[��;OIg�/���#��#̴m[ =(�?���Ѹ���}��2{�RU/q�iƠ��s��i ����f-]��ia���צFh�O]�{�����*���s���A�����g���n��b��}�q���=?��kq�y=v!�|��m������U��^�-��D��f��[��t�a:�G�}�(卭Ӕ�Dz�,ދ��\{�?B!,gn!���T]��0gga�d��D���E��v���V�/�k"���x��X4s��@�+�8��:�4�'�ƬH�'[�dO�����
������c�V0�,m�	�:T4^�'v�즉K���S��u�|j,݇�ť������x0~��nK��D�{ DK�����
wy�����ibO7��0�](�)�N���}�6F��L�T,�,�8?�"ɪ�[f[�OY��g�+mw��IѸrCnq36�ve���]/Aw��T��k����s|S,`���0���~*�mih��𴂺A�>�x�y�U�c����1��lȚ��<�h+��;~�}Cc���ˍ��]<�y����/6���b)'��q�ư�k�>��r��ػ���?y/�%��C'Rv4}ϸ��C��|W����F=����d�dhQ\k�'�c��z���iV��o9�-���R�p'̄%/�{|�d�I�������&-7D�i�"H�-З���>݋�TM��=0����`��S<ߖ#۟���8�f��6�c���5t�[$�<C8J��D�Ƚ��l�d?K.��=���Glz�+t?un=�.פ!ꪬ���ퟁ���{j�֓  �F'��5��O��%?��Ԉ�79qw�oBm݀K{ ���ٓ.�/����۽5�R�M��1�`�c5�c��l��P��;��0M`]sJ��.d��� pj\�O�	�[hlgR��q�L	��O׬�t�dFpH!g�C�`��C��'����*sp>�CÏ�J�n�Ի�:�ϓ3v��h޹u�#;��4'�uM�����0")�K'g��#�뙿n5�t�wY��X9�:
�T����'JV,*ڞ %�x�"�i`eu󖳇��[�X`�گ�6ԌɈ�\�7��#���/�$yeZ��\R �|��0`<�%�z'{0j膎fs#_R��,9,���ZgY�Vz�mҙ��5���Ĺ��0�_;��_r��6=��3v|Q'�+H��6|����Y�w7�<J��b|5�ĭ�"�{wsy'�<�W�@�A�涗zM[m��Z!P}����<������!�T,N��D[�K�jW��J�E�l���p�� \e;ə��	�j�_�TV�!!�731e4�(���>�y���(�7Y�.�Fwg\e^@�Y��ǫ��t6����1���9m��=w�K\��q_BJ�] {������e[�~�8p(�����i^q$�@$����fn[����9����Kqc�wT}�Ų��EP")�1�3�������ig	�񕂗�]�����I���j>�v��U[�G��]%mm��E{ɝ�s�����$rs�^�*�:�a�*wn��1\�?]�X��4���������e�����X�9`�"s8l�l�o! o���FEpK
BU3�9A�:���k��p��D�5wȖ�����6�|ċ��u5k�����$*S��>�@Y�A��Eښ�mJV�S=��n��@>͘u��[���}�"@�^���K]g���p��M�ܽn��h�[�ĝ��a4-p�<.����&ⴶ봈����圸��q^��1|���E�N�<��8Os��,�e�!{�)�qiD��;��c$�5�'���Wz���_��,9i���w�I��Or�1��@�D�.	��gj�(]a2���2���t^�w؀�}Ǭp%o��?�n_7�T�_� �;��:pw*���ǳG���H�N,捋��h��c󜒰�)Y����P��R    ��<^���dy̺���Sen�~>�����I�����5�%p"��~����Q�����x\{c��*���׍�h���/#��V� �e^%iW��ޭw.�mE+ݳn�f��&Q��@x$%b�Nc0I���� c�zXľ7�7 ���m�殻��T�Ӆ`^��J?�M�����S�����K��������q��;-�"��|�����	��^D�9���?�d˩n���&#��$?-���Z��ta�'�yw\7 ���o��s�$�(�T��C�9��S��#�Z�v�Pvd;\���ѩ�~�j-�^����ܧ�5��OM���L\e�y��>�i���Ç�k��+��M�[���s��ȕ
����q^��)��Z+�p��<���&��	t����/U�����N"��DB`�ٟs��1#���e��)c�X��N��h��ޏ?�	s۝ �D2�C���H�Vz��*RE��`��#�ʻUP��!0����I�F��<�-/4k���m�#ո�V@�!r
A�I| ���E7�[�"�荈��w�B'M��Ǣ��m�k��2.wQ��:.	�g4�mj�VJ6=�J<{Z�H]�s�)�h�T��|F<ك�nS�w�"����1D��Oqc8�������d��7,��JU ��1����q�h�����w�Nz&yzO�Ѐ|��4�8y1G'���h��Q�]Ħ�f4���=�y"���t�&x���>��?4��P��4�����ٻE*�����M<��`���;A���E��z�E�x*��䩔W����o�l;H�q�g�a]8�M���q�#yӼ�������fv���,Q"
�������'"Ou@Ws&B��9?�Nz��TJ��勚�Q�Qw��U*P#�}\	��
�NV�v�!��X�ZbK���g��2���H���N����cG�����HeQ\��:����p���
�QAٓ�g���z,ڠ�o�!��në��IF�beR������01�۔�x������ Q/号��L�`+�)�%ٍ%)t|A÷��簕z�wm�
%�Or}W��e��fm�΍/gq��Oe��YR�.y�0��w��.$Z6�G��m�u�N*�T��n�^JE[;���j�Oe�o�>�R�r�Lr�+#�c	Dsа%l�n`����sY�+Kļ��\pl��q��NEMD�{����K��	xD�쪼��R�'���$�Vs	�?��|)5b�;d�Q7��=�N��d�g��E�����ɶP�x��'��������k�*N߆�r�+S�L��є�@���i���@����[ׂ�7��~�ui%U݌�j.�z�(�=���f�{T�cMY���?UEl���Sw�.�����Y<ty����ա+��~�� ��W�B_;`R�jϋ^�^�D�BM��U^Xe!�O˛�מh���db�9�?;|9�V����qp�72]��'��5��X�|Ub	C�L�lҟ9�$���3[���S
ɻΪU8/?^�劥���|�Y����T�@O�pՏ];^bz§`]���ws3X%g����"��ח e��IPcZvLJ{��墶HdQ��e�_�h=Y�|Ċ��R s#�aF�w+t�a��}	��\ܴDA�9������x�����it���Sy	�A�bV�������'q�J��埢��}�9gq�_�J-e>X{ $�-��]�C|����OD��f�|��:}��25Z)e?4��J@i���_�-�m�]S�	%B�O�(��^S�ܻjP{� Xv`��=(�����\���+FV@��]�u5��$�����5EhQ��H��$�[Ԭi�W
���@�y�[e�$>Z�:��=c7bg\�S{i�������*?��(������Xԥ��.h�^ԴՃ)C<ٚ�/KP^���[7$L��@����v@0�N�B�97vgF��4����M�}�������W��[�Bx�r�m�O� f�S]2d�8����äo�@P���uzKJ����2?w�A�e��1#˪~zG�t��]m�'Έ�����G�iuh���?�=ߵ�hp�����N
h�\���6�]��uމ�W��u�;�E�^1��j�=R���k^$1}E�o��r���aeRi	��l�U]���֗Հ0+_�G%�R^\k]�;K��*c�%�gQ.	ߔ3(���e�k�zZ��S��R��Y��
繲�yx:ߎ�	��5�œ�M6E	�2v��\�R����,��T9�+Ӳ8�(�'#b�5Y�Q^?/RJ���?P�X�nL��Je,,��0Q��|���i��)Ǣ6:D>�!��T��K�;7��)a�f��0��ʺ���:|�cA	X�w}r83 ����r�~f|̵K/T��>�jW�Tqd_�Ϻ}���u��R�r�{��´a���W�f��J�sb���7aS	4U	U&�ViזV��4;ձ)��߃�*4v�o�4(ݰ ���+���v*g���\2�M�#����K��TR�8���;�OQO�m�>�'
ڱ�V���C��Z}ahz�l"ಕW�4�id&�hO|��]�K[�cI��u�.����^��YP�xR )Vɩ!#n�n��}���xG�(gV�v'@�݇�U�V�hl�<^������xy���0����/}�
'�x��h0RM/X��,�@*� �?(a�ͼcjЃG�<d7�5����c�W��j ��DA����c!��<ؠ��t�ͤ����J�]`���?���h��0�1�!'��a�68���WLt'�����������|%u,3I$��� |�lBK`U���(`LE���}�e>���v!���l��d�[����JP���
^P.0�!��OɈX�ț��E�c1a6� X��1xi�<�GGSf6��O��j������,�ь8�O��S��"\e�O�A&���`�uV7�^�S3�i A����=�y�أ�T�����IB�Q��E?)�a� �Ӌ�ˋ�Oc�
�Q&*�Yw�	��L��ևU�N�Y9�U��(�C�
��V��)�o�I�WL�jT�"4���-�Uj�s[Q-� �߿�XA�"1������D�'�/���'�m�kV�jIm���C��Iy�Q~u������LN�����[�ƅ����f�>�fK�������W`á6���7�?��n }t��7���۸���DF%�?^�h�\]�Ӫ�/{�mZ�,Py��!I�J�RD�v���$߱�䳎p���Ӓ磁¯
[�3z<b��A��8c�*�ꕊx��6���ka�jI�pMY$����I�2����Sd�-2b�Ņ��ѢĲبRSwٖ͌��T�:���rA�볙��2#X�.ߐD7ӗV�\:
�hl:�n�1�aIW%TA�D6=�3CG3X�?�9�5�q�dwHl�����%�tr�%[K�kv����i@6���_���%��r��PI�7l���?cTTq%�l'�0~��r��Lǈ63?IfG���ɽ9��	�x0�NXK�Jz$�SyODx��X-����jY��+�\�A:�� _��I5�|��^i����v�N��d	�W�X�Q���w��I7�]ܜyj#� �RiL�}����.
1��1�<���4�.c`�Jc����<&�=<�ZqbI8h�IB8_�=��I�ɐ�w�2XE�R^K����iJ����h����$�X�^I�����\S����1"�����#���&��܍���`8�fA8�Q��Ҕ���0}���}lUC3�w�q��cMu^�u�ɳ�eT��`-F���&��NƜf�|�CQE�l7S1�VS����m�:o)at��b��jX��_��LO7���U�����I�N�S9�r7�j��K�D�����5�����>����-�ASsA���K	1T펅�eNM��(qf��ذS��P0h�N�ܖ�[��D#��}(�J�~[�e����W���e�+Q�[l]t�o������'5~��-��S�B��p,�:�\^SJ�{ӏM�k��G�5    ��:,�5$t'm>Q�,k%7�A��.��g�n��oh�P�Ƞ)�h�nZ(�yF�	i��Sx<%��1�攦�u/z��p�#���w,�-���Ek��4��Ί�L�;��R]{�r>��-.U2v��	���Kɭ-~:E��E��0ם��
"���(]!��`'��b�����с�O�P�)ǳ�Ē//]�{���O�2x�P_&\r}F�������;+���$R��
o��t���`��%�Y�9Kk�T���G
xO�Y?�L=��çdʽH���JC5�e���33,��l���tz2I���;B�t?	}�U_��ą��#h���aН�;7�6�PW1dQ����+�Ǻb�>/��{��
dKi����3��f�,��Q��%�����c� �:���o��҆�vN���Іe��6�z~S��W�/��|ا�dN��A�@�/�y>�*%35��8�Φҏ���)�����j���:�kP�o|���2h����4��~�v��jz�a�����@�}����\%(�C-�,�;�Gdpǡ^�h�6�ΰ��E_@��YI�����G��9���h.;_#���
��;gz4ƫ1Oi�;�@�'czɹ�>5����#"���Ŕ��O?���2�˿X�+�s&�/b�g��2���a���}�NX���)�V^j���fv�"Q���$u��i*�]�Y�-$H�~ֻ��)|�d��\�H��M�B�=�S�ɫƫ��&��O�d^W�R�w��	g�%�W5M��fګ2��0�?ʣ9���&�@�.�Ђ�F�SR�i�O��Et"L	L8�S�Z�+��%�?D8�2P3�(��6�ݡ�2��Y���7�ԝQh��a��ڲ%b�n�9q������c�yw�$u}Gg���-�3' �c1}�՝.C�Z���E�gw����I�({9�3��2���)B̩I�U��A��6��%hǦ���!���\�S�?�hW}Qa���w.E�	GJ�����<3�__�_ƀ	�\͐��ZT4ٮ�EY��4i���
ܱ�U&���|۟O��j��Pa���&[0�sۋ⟊i_j��h�����H�΅ؤ�LwGqH�P�KN�B���,Гs]��N	�E6`�r�#�>7������������t�6��'��Vq���8}��+�i2�s��H�q��5��S�Nw,._���ٖ���fo�[>��ύ���[�o��I1�:;Q��@v{��T�����|�x���QZ��-ӧ�Oe�O	�:Vݞ�jp���3l�C�<FS�/4���#��������3Y��:��=I�`�6�<�����t�h�th�d�8�_%��@�ց$�Ŋ��������ʅZ�N�o��||��c�z6�X��R���u�������{�.�c���P�J��ol���X8_��4�{	�����=`+���';SY��+C��!ƙ�I �,�<��~c��o^Oy�Z:5*>�M�^����xj%87�K�Jf�����%k�P��U��ߋ�񼇢<r$K���s��W��1���a���9�򒈻�w=3�3L�둛w,�j��~3u�I;Ϲ<w�D��c4-<N+�caTi�$���h��O�w�(��Y�+Vk�N�&�!����ex���&��2s��l_���_j�dx�},�D$�<�u��U�$5�r�9E�1��이Se�׭�A���~��E�W@Q��[Re��2޲fQ�����@Y^��XZ���Jj��2��</pro%��VY���zdߍo{���^���%��y�ˊ�#Xr�Jn�c<��T��V_�'!����Q��eNB��yuӓy�&�ꉬ�y�ʂX�q�dW{��ȾcJ Reh��$h_�NVb]����%��W��^ˋb�8nu�b4-QWc��w�d��Un�h�S����Z�A[V���}�޴E����D�256Vs�|b!E��e�uT~T�3�?�_�l�T�ZH֞|�dg���!��M�AC�Tc(�QW���.ˋ��y�|� ��S��QP�7o���c%�k _���M��l�]r����*��+�E��S
CT���*�M�tLG��p�xU��E����.s?�L�AM6���Rk���S�`,(�	�� UB`2�r<\SkzR;_GK�)�N�X�z�E���u��svhb �Xl�L�OR��뾮	��U���4K�C��L��ajw����3���oO���m��k�
����bV��kj˫J��;ƙ�|��Jb�S��^�1�~Vc(�����(�r I9�}�>R5@Y�^��(�U)(�S��zh)˚;�!	�T�����W���%�E��|Eh�y�cD���q���<���|1ت�
�jk�1U�%x4d�$6?��ʏ�@l<䟊��-��<v�D���$�tWJ�
Y����6jl�,��d����#�ރ��ht�{���W��$ӣ�jIf	�P�o�X�]�ӛ0⇕��H���?K`Nr=�GHd�øqJ:%����7t��_ۉ.��.�6x�5��%V-�ε����ԻԽ� ��:���''Ǵ�.	�'������1^1 �%�n�g���E�C;�]Ί�o�nI�1-����$z��(S�x!�8���C'�'���{��*_dd��_D��1|$<�䜷����*7��O�LF*���`*j�Ϸ����s[:��O�	�r��Ǚ���괷f��1%_�zm�� 5�;�֡%+�y��C4g?X��b*X��Dq����4����9���m������z1��>���"�Wr�[c�]Խ�Γ@�(��{"qe�� k"$x��S<<��A��]�c@N1Bl�o�;F{�:My�R�E���O���ë�5mIW��o%�n�:�v)��X#]�כ��ГI�;��C���.Z��\�=n��ߍtd*Y-q%Ze��k'Ҍ���pD���%H�q���٠���3.l}�����wl�;8!��D�j@�[��ڿ�0Y�A��u� _;����n�,������r�KOXU��u�kd�ԊK�N)�>�,(���l�������J�C�B&1k8	�r��|��j*�܉%p��C�p���Ҕ�W��������l�%��J�Q-��dh�x��U&�ڛ=�'�j��y�J^Z 	�H�D
 w7��^|��k�13�w��_�[�[�z��d�S��^e��@�,v�o�vW=Z�B�1ޢ�U ��i��<%�>�K��@ܱ�޴`��Er���N_���KR�	�`�;Ak]ÿ��F�7X�1T69�`�n�˙��xa�&qy����J5�A�ќ֖л)E�dW�'A`�6��ܳ9K��u�r�vUL�����-vi��C�tz:is;��ɤ[������ٸ���"�T�jl�lhzYqVv~<�?�N�m5J/ah� ��I�-����5��a8�]ݥ�\s�9Ĳ���=�Y�w��dP��
�E'��E�����)�����qĞ���8+�6T����O��!�*u����=<�ۯ��Ξhk�N���~��l��=�+���ee�ݠ��sB%����*��t����T����|iZ	�qǀʍ��=�'�����.h^�=�h���\��O�0zK�=�[�D�`������Vc^-]s�H<w��x%������;�`=bL^��K V,�]'��AU���L�A� |��iW��j$Jى8�q�@X���Գ��.n����M"�a����w�V�MQ�^�[K�:���`ɫ�5��C���ґn�D��i�4�L������ I(C��Q*�7��$��:јA��r���L��
�Vl��R`ꫨ�ZQ�>�J[TǄlz�I.����DbFbۧ�/ѫ$r�M�`k�ۜ�pQ- �1l�Ֆn1/�ݨ$�>����F�'�5� _�v{t�����,v�Z�~�a�|P.{"4K|G��� ��<�#���㱪��m��5X�{,�:%�X㱖b�W4���P�M�����a�u���c��A�PS��������s�c��[-����yTu��E�����yv�^�1    c�T/R�cQ`�X7�&E�MZ�?�����n>���ʓp
�_f�R.K=#����}����?���@q�)u=}�Z^��TՔ�������S�z6n�J�v�ǚ�o�S����n�#g}G�7*�FQf���-��A9�s�H�V%��"c��-�k�z���S5iJ�x�(F�~$�E~��=����Q����[���/Ag����u�6�ݩ��E��ѫsv�Rf������4��+e1-eq��#�ۤE�)��!�|��g,Y�	}9Of�Ӂ�ǓT�{}���ģ}�`�z��`��_�p|��sz}�#���S�J�LMݝ)�d���`���D&�q� P�]��,�����ݏ�z��-t��+3��XP����C7"�rqh��D�d͆�z.O��p�l�so.s.'J� �w��'�j]ӆ�oc��$x�d��Q�Oo*o�$ye�u�w,���b�=�v�N�m����9��q[Z���� T9Z ~"2s(#�-傜�C�wV��rp�q�;�u9�N����Y�&��du�gS܌�$ԁl������*��sb�G��'E�D/\ZC�݇pg�C,f�g�zX�|�� ��Fc��X�L�Đ�0z7��}�D��=p��������x#��3A�d7��ڀ|u&j(���p��5�J�|Mϋy�y&�L6�T����S�(���Vcww�P�hӊLm�`')߁�:�s�\��8���Q�����$ d(��3Q�W]q��0r>�{��g�0c�R��{��� ��t�d�J�g!�9}����
��������� �)!/�B��ъN�I95swЂ}*�[�ĥ�����ZK�{K�4�A��B�d/���t$u���zU��B�%��N��˚q<479`=��u��Pq�#jl~��Vl�$�����0.�[��\^�m9�3W�n�+�УZl��j<�(fpj��l��n�m?^*4�<��A�*��R��gk��H}�bS�d�5"
xRx��:G;qפ�ը��:[��WL����F��@k*�z=�qjN���P��Ov�7��8������;c}���T'����t�����+Dh�&|���WP�ǚ��<����۸�G2Ѓ��b�o^�5|8Y)架��[&��݅:G�gI& �B��<�t]�욝�%0�1`�G|Kѓ|�Pk~�jQ���M��+�4ĺ�Wg�����!�<]k���@B�Z��|$UqJ���x���/�%:؞aChY���^��K|!���5�y4�XL	�p��?m�BX��SR���r���j�$���[݋��Z��(991`�;�à��*�59 UW�����V/ɭ*%��Z)�}Py�y�1����߃(��-P�;hiq���ӊ�ñ���*'B�T�����6���І�X�b�w�Q������S�]�
���;��
�/|ʵ�N�Br��f�>$��j�0կ��^�|U��=��׼�C?�K��Ɯ
e�\{���S�(��jNW��h�[:C���F/�BeK܀��}�cX��_�4�M�N����i��#��5�����"���<�H��ʼ��zU�u����#�_��;X�2�Hbj]c,ӕ$��g^�&�gCג�Y@w۠�YLz���  ����9's�P�-�����7RN\�=w���I~t$�K��0|]��z�,�R�.�Z�����-H+l\'�׫0���ձ�[k��<	&x�Ȅ�]뉓2׫_"-�l7��[��ٱ���F�QU�u�v��K��R�ޥn8����U����@��Q��Z)P����i�b�Ca4Oy@|Yw\4�MK��0����
����|�t�x��ԈJ�\�������,���jp�L�l�1��G��#��C�;��{'��m�r�-Yҵ�t�r��K]�`1�A���\@����w=�󖵕$��`��
/��KMN:y��O}]��'�j�y�~ѣ���ֽ�V�T�?ņ�0�O^OJo�~&eq/-�~"?�(�d���إ�,����1��A}_����	R��4�pY�j~h�6�ōJ.C���>�EͻG�ž�E���`J�t����M����I�R��t����;���b�;��4��5/v�$�����
M���2��Mt=tH���W�E��6W��xS��V�iAE�����q�d�lm�����m�0y­®$�_�W��F����ӕ☭�F�B�9Ъ?Wzb�uw���_�B����MB�"�8��</O��9�l5-aaJ�*����T��,���*K�[��3̶�=qS��F��RIj>���Y=��q�{L��(�a2��z�幼�
����@�����&�q590��5���`�;Fi�N���:{	o<Ԗ��ϋ���&d�:����/u�/8��	[^e���vA�"��'�5g����H�C\��lY�����t�ɵ8*��#�!c�\hg�����W��^�^^]8�`���VK޻����Cy�f�[��E����eg=,��74~���*~���D�B��g��q�b)�x�K��H���)t��"Jk�:xˊ��&Bݭ��N�\R���"9m�J�p�YY�rJA�ŉ�W�y�<]�W���&��}DE	$��ݞf��f��"���=N��RnV�N4�q�QN��̢�xS�X͹�'Hl�����6+��6�i�c��N��eTB`&�I]��-�2X�2XEHe`�G�����~Q�����A�{�km�œn�ϡz��T��e>md�FNH�`11X�nӊR@u��Z1xiZ7�Y�5{DP2��*�UI�X�),�D�,	2��ݓ����fT����Hz�=_$eۦ!G�'gm��j ;&����/g��EӰ˄U��aY��@����*�C�/�u�6(߸�ɦ˳>6��B���HV`�R��~Z��|�b������cL���I�B�+(�]wrWX���UcŴ�����!߉f��-���V ���eJ�l���ls����myY���.W_sY��%�L���	-�H��C�kEl�����KP,��Hr�\���S� ���v���=�n��I4N��tB��-�bL'�t���ѧpq-j.�,�S|��Q�5}�@±ZAl���m�h�씎���G�U^������5�c��#&�g��`~Om��fd�b��Y�ڨ�P�S%�wK.`���W����-9��&��^�[���C��S��-��D�/x!#>#�f5@7�j������K����%V�u +	�����!�Gaת\�߭���e	����5՘��T�eY7u�%|X�YOD|-��)&��/�#VE6����Lo/���I�DJ�WϷإ.���"aQ�Y�e�0l|�4Z�A.f�	Ҥ�N��%5,=��YT��@b��bxu���r6٦��	mI�\C���������hl�VPd�����j�)L�V�!�Z8b5�"��֤hb�ĝ� ��l�l��1Y�3���k�r(����L��ռ[��6r��G]~���ͲQ��w�����i<z`���J}1����N��G�hapK[�������{�-�mN��t���ů�y���I�z�D^<F^,��+�0�>^u�Ӟ_]��C�~.%;��;�A"׏�y�Uͭ��m���_�K9�v���+Ҭ�{��j��� �Q�a��nw���;ݿ=`���7C���mZ��Y��eg�>DW�5$���WQUYs��PC��j�!R$Y,�Bǩ]���/W��:0	�ٖ�Z�m�����(%�%q�L%Wi�4���<$fbY؄hλ'�aIR�d��wtq�OS�"j@`Y��ܓ�cY{yY��=��j=��DƠ�Lwv q��Qk���O�i���O��ˁ�5]��Q
��Z&m�dj8��J��S��S�{0��g�k�Z>�1�T��!��r��2A�"����"�r�O�.����@;����&��m#^�d����0�^i������i�;O��H�i^[+������Dz�%D��"��H9k��3-�. �(o����Nf��>Wܜ    xF իzṴT�n��Ca�.Es8PM%��Qq4��-`l�B�s��h���R�x�S:�#�:�Fe(U.y�$�D'���S��C�!��[�����_;�S��R�6��|��*������0"�*5���b0�����D��g�?�7+���G�U�u-?۵�5��P迃 a�x ⴺ�_�;�hBB}�騿���^j�.fC����W�4�F7}7<��(�ծj��j��X5]���0ߟ`�J�eģ�,�0}IjcK��cJ��QUw��P�]!���pH��: zSد�$��:��٦� �K��<u�2�U���:��3i�g�.�3H���L�	»���WT���j��o����<wE�է��i���*xi;���I�N�(�E�/�<l�<V�.�*Y�W�`���׫���$5����N�T��[e�%Yj��}1&�H-�7��N��"=��cl,�����Uf���	���ܺ/YU��C�+7!d`-z�K�d2��K�8w}�,���zTj��B}�D(�.������\�
��0,̏I���/)�/4}�!&��t}�mC4�����)i��d��C�^�i�]���.��3��u�2h���v�`GA]��P}$/�O��o(�NIQ�b�j�<���ڧS�����/V�ԗH��f�v*�ǰ� t=AR��l�';�b�����?��;*�#�����$Ě^zأ�zL�}J���>{z���!��%���J���7)���);l{]��߬|���+
�1E�+8!��O���>	�yg^��@m���U6�*��ʥ�E���wP�Q��I,
�G��h����ݫ�+T#~rն�Mm��6���m�3�<�M+r~Y�=��k__m�L��J���C,޲�p^R�&�'�Hp>	U�>�k���`�������혡f�ۣ�'�Β��Ƞ� ,����	�&a��P��㽕�2�4���G����ϥ��xm�
m��%Hm�C�1s����v5׊�%�,�c�4�b'vh�Q�l;fm��"C��N];�ಂJu����8�����^�)����=e0@���X��r�n+S_1�M�(#;
<6��'�~y�d�8X���"ugw��O+��L�>q��FZ�SP
�ȗ(%�c/���u��K.ީ%ɬ��IS�=�|ɷz��f��Y��@C岵�0�����VAsS����}R��D�Np���úW] ���xw�?ʙ�P̄�p��I^�э[�����������ޛ�2A%�F SX� �~�����#��5`KCCnV�1�SO�Mi��2M=3!��,H�e#�;�^�±W]���eem���.�IYN�cÔ��,Lk��r�
l�󔽈�۸;}bF������2�W����ɜk1�?�hU�6zu)��Z�2�A��A�O��IPܨY���Ж�ɶU��Ms�%j�[�O&�� C�V�s0�tp�Ki�Ƃ�a�<���$��n��E��N-��Iݎ&G�\	�4y��VN~2\����	�n/�ZiFM�<(��������)��tp����� x�_��&�Qv`ml#Es�Ϡh�pk�E6�
4e޵���6DJb����x<�
iM+�[�I����a�0>+�/�Ev��Rz'{�Y^�'^Q���T�:*�-�b �f����Eݫ֌�&K.���'׻�l�d���r��0w����)�\�9�|1�0/E��_�:�Sy)����9�P���a���i��F��{��XT���I��C$�i�m��2_R0�K�]O��ȗ5!|S�#b.�[��kt�
���皛�D���ߩHI�
���W�	W�ħ�I��̶��^��q��{�l)}o���{����h)3!�w�B�+��w��hdԶYd�T�Đ�kz�$S�E�W�N�i9V�Q��q� a}_�A��τ��k��F����d�AX��T����m6��l^uK�G��rD7OG*!H�1�N���P�ꮶ�W�:��T�����6f�������ƌ�$*�Y�佢��5��qe��C��b�|��0Y�pP��XF�(mR��Yd�)D���K����$�J�`Q�P��-�,�oT*���7���TSM"�/�ǖ���	�XV��i�?�$#�IF���qq���kʐC�X��l�<��M@*�H��9Q���2��ecI��e����.��Aխc�,�k�BϞ�ƲS���58,Q�4~l�a�	�
�ٚ�^��`j���%[�q���K��� L�jkh:gT�R���`�q��x<$p�@L���r�\)0Y) �4���r���;����>RR!`����X������=�֡��a�]�e�n<�d-T���1���;KV6,#�D��{K�4��Zٍ�Ɋ5�)�d�6{��|���ۂW�>����n��v�Q�l�����U�4��ׯ�dȳ�v��b>��qO��D�D���:�e���d	��TG��#���RL��ʋHR	,�Se����·V��K(RC�פ�Y�.	�%�e�+J�ͺ�pO�-���\=L�ꉾ�����i�j�$q�Љ�i(��v�Af	��s����4~�QΖ9R��4���9R�N�KKK/:���U���'h���"��5�F�H3���������얩�i��4ioZ�_�c�bO�W�ҙ����twKi��i:'��ᵚ�'�;�]����Xn.�C8��*�h{��I�Wc��D�~ҷE�୚�ŨevR�gT�c����U���*���M����ŴyퟭLb���u�{�~��-�W��R��g�8�ʸqw0�oʡu��`�Yy�b��rP!���\C�$��sT!��L��u����x����+��%�^Y��BF�$��`����Z^yl�lӃs��z���S}k��Zbm�WI�����U�QYl�����O��<ъw<��t��c�I�X	>#f>
�j �8�(DoO�*�몔��-I��Q�k�,3:�{��% B�_�/�9��Q�����qy��(&]A��	��h�/��$g�#�c�����h��æ�H���K.��'�z;�:&BSQ�Z5Ի�����Z���?��(����m��p	�@!��V�[o�e=Ɵjz&Ǐ,�i&�0%#���vaV��H�DC�"��޼�߲l���{��"A)��q}����vR����Z�ͻ�W	[�A =ֈ�3IEK���qpř$�=�C\a����Vy^f؆��J��B����m|��|�Y�F;�O�;�����t6SS�H����=I�e��m�e!M
�/�W5O(>�����l�?}�����N2�ŵ�H�}3E��E�@
޼�E�Јht-S����WD�	�*&�NC�����B�-%Xh"���b�(��	Kx6����Z�Ӓ��۾I�SK�#pT������0��d�0�]ɦ�(���5�O�ԡ�GRJ#�����Nv ����qS;���(�T#��H��*���O���!��Qm��o�3�B��r75�V%�D}4��A=� �7�2f��BS�]�����iï"�i���A�m�����w2����Qr�����\ޫ� �J�|����HOT���Ic�Q�&��
폕R�S�l���v�_���V�M�Pe����I��!�t7�-�ʏ��ГƎ)P--�K�f`���b/F�Σ�L靤��_��Q�~"`�*DU'�c���PR�rD)��J�G�[I��2hC9��9!;2=��Q=�f���s��d�v��O��N<r��'�C�e.P%�.�S�|�����Ba�)Vٔ���)��O�ڨG6�~�ie�I9�����xF�M�m�x�R×|��#��7l]e^*5�
�h��,�����ʎc;^�����RL���?6F��y�P^���  �⽅�O+�d>;�F(m^RU�T>����{
`��Ze16�'?l�<^�y�n�(\�fr�&�>��{�� ���!���Lǳ�ďNT9��9�r^~%�kH�^_T�5�F��t��*����/��    ��$c ��@E��(��CB�����C�`O+�a�Q�ɑ�>���վ��j���v�I�<���^sۗ�FWjC�44/��φ65�n���*싖2�c��0���!2��=�u�0�����F�f �c�:���[�c�卩�1SiV����U׌�
4��5c*�.w�|)����f8�f���zo�l���5R ����7��_�&cJ��n��w�Ș�~��)QС�Θ���^&0"�ׄ:����>���,�2'�����D��z� �X*��?���7n������+���Kc����k�+�k!%R�Sጂ���e���9���n=�|��*GƂ�TW"�$�-��-A��_F��[\��k�*��#>�f�&�?��S�/���
ww�t3#��f¨����c����	�=-yWE�,��H�l���|��r^��<��nFB�p>6�S!o% 	 c+%�&�D�=c	��@--��������{����D9�d�5�\��VV_���|��_iVR&D�����퍄a��Wv��h�˾IυnTj�'�f�z(s���H��M��8zu��5W�hM�r|�]�����(�h�B�َBiC(�rW�C�'�*y
u���&�^�ELS�HɎ!��ei5~h2Fk�q��ׯDA�H�l�����Y,���1L���Ry��惹�=�����S4�;Z��BF��p�[L�ϗ Ȥ �ԊsO̎�aH�D&�:{l`�Ue��R&BT�;�����/���Y����v�N��U쪛��2Q�J,VfI y�"���P�K�WQHxm4:�W�;)$7�2I?��\�����7��a�hb�ʾc*������^[Jq�Y�����Ej���	0�����XHc��Fއ^�uYa��J����;�,�e,Y9 �}��e	�
F�O9+H�>�5#o�ecQ3��x@O�~�ӥ��s�7u���Y��a���Nb�Sk����Um�Ԧ4P_>o��;�"}̮��Ke�*�1�T����B��f�C�BӅqc�A��(v6m5N�k�h��l-����	��bj[��]�k&`�=d3��Ţ6+-=�ióMԅ�će���K���YE]]&�ݑ���j�֢>�<��(,]��hHCא����r��57ӊ�Y�����`jv�#�9?�Y�r4�YŽ^�4�aU����S�k7�����e���ٍ�@�Hb�O�fGa�1M&s��0����5;���}9�cQ��c�w*������)nբ�'�&���_�A��(�[-(s[��E�O;'�6y����k�\�@g �{�����@3��^5ܦԨݮ |�
4����c/�����������dR�T�@2��B���u�?��q�,����c��lΩW�7=�A�B��Zc�H�m����)�6)e����̥�J����4eL:~L����~7^���*׳�T�9Qd�tQUm�|�fV	Y��)<�P���/?N;
t�+g��3�=:��ch�+4܉�t����2���_�-�7$�N<*��J�_���� ��zJ&�n�Ӱ�:he���INj�_��.��F.�נw.�(8Ū����=�|,6o��,�[��u����%�ۏӔp���mi	����Yt��6�t_��SUR���d捸%2����S�$m�x�T8wB@\P/a��p��{/f͢ ��.d��R��B.��TB@���6�Q�Th���Ey�S�ث�j��W�\@��>**;|�����:[��)���Q�Eb���E�է%��#����&ݶ�Vq�N&�;�-�c�)���n��k�x��������m�W��/�Z}�X���ȵ��t�ױwj���?�?r���<ӂ�c5S�ݝ�~ʫ��l/�eY��.�qFv��\�-����Wk�S��l\����L�z Tf���Z�P���� W��v�p�ߦq=Ck���ᆎ��4Ƕ�h}U�UR��������kQ1Sa��%��Dܗ�jY��U�;��鷔����.ȭ� N�e�F�U�R�i˷ﯷ�-q��>�.b�T����&9���K�a��"����(������X�5�s/��L*��T���y�P�������T�)�V��]0	Ħ����"S#��O�>�2Y^�#��rm.	�_��}4X?�\�`�NkU(�-'���&��G�R����/Xj����|aYRy�Lb����lkG0�8�(W[q�����[u��Q/�'MC:h���z�f{��TXxǴG�q���;�,/��IƎ'�:��u�K�A�ɕ��#�)x��i��aN��x+`�����jpCg���咂:Z#�I�0N���uf@�P��Q���gX*��7Mv���)�����VK�X���ȹo֭�_�:4D�NGo[�?�v�T���>��Tp޲�ĺH�TM"�RR��p����%�#K.�9H����<aw�T��h�+��YbJR����ذ���=��ڢ�:*B�j�*����Kr �Rag2W�U%��NҷW����P"����G9�K�u�d��ȩL�,�qg��˚D�)�5���;����Zl�̎ ��ᵡd�%-�>m��f���l�����։*����FQ�C������&#ń;e�^�ܾ��R�Dݘ��u@�z󔇕Vk����QIfM���������y��<њhp�����*0�W���$��&-���}oWNwR���N����|��{w�=iZ��(>����Q�����M��)t�,�	�.��c/"���/?���8+�Wb+��0(����JOyr��H�Z`�U���6Ψ��23�N�z
�b�b��b߬eլ,)�N,^�q�Z@;Zک�� �N���"�2#Ar*��
��|r��D�6Fm������N l��,Նp�5�wC��S�)e=�iz3��qk�9=kH]ݩ9�k� �J� �ѐ��)�l����n��T�t^F�&�%��\j7I?)Mz���Q�Ԙ�9��6�Xh��{��Ԭ>��JrE9���%6fJ1%��_*D�\�iD�����T���~<�K��`��k2DY!TQ�u�jי���-V�u*xxٯ8�V�/c��ٗ�F�VTifd�,�{"3�_Y,������ �D~|��̣��u�����+�o��A{�ꙅ��d�{e��斲�ݑ�3��:W���Iۼ������#K�r��ВG[ꪟ>�v��0yȀ�*j�iJd,&2���� /����M��~��9H��y�XG5�~3*4���G��#��I�+�3!�=]b<���/R�c���؍��N� BU#�D����7�-�9u�hӸ�hyY	
����%�O���%W�ӖJ j|u�y)*���ˎ�S�m��jKp�ڌwAaT���)��?j(7n0�DVW��'���b%�@�x:�C���}��u#�������U�,��@B���f-_��hVޱ&B:5����y3�*�����WK��@�Rq6?-�j�l���r)��w���	ʵI�n�����Ȏ�X)m���p"�[pK�oIg��ڑN�qk����[�+���{�S�e��}�0/��C�!g���\3o�!��Je:$;������w�N(�3&p
��ъKr���h!�zG�T��/�ݴ�`q��4[⦯$��6�:�D6R�ﱷ��o�~^��ڐ�;����R@t7�@uow��r��S��{���}��q��g]��Jg�a�Rh����+xI=w(����nt�F������Ay��n����lY�Aڤ"�h~�&R�*���ʢ���S�N�IƮ����W)le�yw�Bh��
nv�e�t�ƫ�b�� ���?O�(J�u������+#Q9�N��Hݐ�2�)�T2g[~(��"�|yo�m)��fO�4�0b�`��R_�f������\^o�Qb�FˋVT��o?)�y|�=Ϫ�D{j��Ԧ6������S%��C���"U=���%�;*73G{�}9�����"f�Un)M/��Z/��ܤ�(�+)����6���ȍE���r3U����ccTd���&�T�&l!�x<�k5�^�N�3����\�-�t��
6%<Uu��Bª�.�    ݡ2{a�+>��q��Q��I�D�д:lz�[��Kx�����"�5k}D��>��-�4N�)�Ujp�T�o�4�Ǔ$��H:>�C��a��Ŀv��f�6 ��:��,�,oe�;�}��b���[E zP��p��ݶ,�V\�6���*C�O�j=Q)<��/c�g�+�8sn�3����:�`��y�G6
��#�7�p���+�R\$'��{C��[��{f�ʲ���\��c��δ}�:��d��]}���C�''���t���%��*Y�σ+sM��)oF){S���GE4O��I+�����ueu�֜��a����;a�ڊW�~��n���od ��o����{�<h�MM�+h�d�yP7��O(�S��ֈ	=j���o�ex�IbpSb	9�5�IH,Y��8�����㪴��M:n[#&J`w㑻��H��t��70r�y�94��!�]�S�y`�<�Ct,UC�%c��I/\e��n�"QGc�te����#��'MX�F����NA���h�R�4h��p2{՟~U�?E�%^��_L�W�h�tgn��Vf��
���	���4�T����#-��	�[ {�_r���k��O��2syrr�����Q61O~A.�Q�F�W'���|d�Ko� ��DW��J1Ԁlͳ㝪�S�*㒸�Ȑ���#���$֕��"��T��%a�P'b�)�:KeW�>�4�}�;zK�|�T�g��!t$��i�X^��-&&NS�?�:+*TZ�����%���7%�L�W^ٺ�{�M��&/�#v+��b�����%ӻ�q#���晶m��6|$�a蠘_��b����Fj�{X�>�4i���p����+~� ��C$�y����t��7�Pω���㧃����J�kN����<�����Ǩ�>B<4)��F!�[e�4�%�X�v���o~�t(�[�����e'��b�;zzz��0S�2�b����Y),�>��,�>��[E�R�C��t4J�/���Pt���c7��A� 8�g:Z�Wv]�,5�V匪7k�	J���g4me��cI�,�0�6JzjĻ^�s�g!S���c�L�{�>���ONuX x$�y��ING�
�C�f�Zf�٭��0C�a�㪼�	� �f����-e�C[:�O��?�=���9b����h� �^�iM/�(F�Mt{�ާ�~+ x���%����ژ@E���"�#�Oe�gi�tj����N'Zc�3���9]��� �d��� �vx��)6��,PO,77^�� rs���=�횶�"�g5U.�C�m#��X��>����7��V��H1�aZ��5�����&�k�/I����6�:�o���dõ*�Ux����o=_AƲ�;P�9!=C�KN��ryVص��4�%J�q6Ƃ�cS�6G��U�r%J�Ko`|vӹ���� _��lT�M
Df1uI�F�Fl8�ܞ��8�+�یD"z����0k�T�:<��>{+ܚh^tܣM#B!|T�n#�9�xC'gPH��rbhC��Dj���w�j*;��z�5��ɠ��^�'xG��˙NY���	�+�~i��'�ӵ�x�5�W���^�a����MVl�όMW^����G;�"�\��F#iE��*��,�>B�%]aR��А���PA�LX�����p�f�B�M��1dedpu5y�d`��	�;FJ�U�wa�
�w0�����d�3�ē��?%�w�Huժ�"�G���<��������Wg$Vz�G%A�n燾��r���!I!��!�؞��%��(����0pbyڱrS��j�n2��a���dP������h�3����{j�8��h�X�]׫�����n�rMMV�-�����d��Oɡeɡ;��2�\��8�����T�si����1Ui��}��\&�L���,�D�|��L�������$�F#=Be���]�
H]K���c�O�fD�NGK�y[7b�gl6�����A*���F�<��Q��X��P��鈊�m�w,j������,9;G�#)O�����G^�A�'��x�.xB''���Eu��Й��	�f�;H4���$]>��?#�&}���C�B�SuxM��3����2i+�;R:����DZ�j���'�Q�G�V�Dq��#Њ����%�&����e4g�/-���:'��`Y�^��#i;B���Z��>�U��w���k5�9-����K��m���U���b��=�T�IVp&��P����EQ���R����<5��e�B)���IS͊dҴ�z_)3��B+��h��wp���-Y{�h{�����ҢFs�R����U�&
*���]����Rg����OJ}ID����=�F�v��@wl�L��\�ͥw�co^�¬��2�1"�h�A�Z�NK�ޝF��KO8����6K궑 Ê	�0�$���6����hHM-Xg~�%+2VR���_vi��-��ݱJ(q��e�<�vP'[O-(*x�������})�@Xѹ�5n���#�1 �p����� ����@�J�F'���''x����,�e �AТ.)����St$��ߊ�5{��,�����>I���&�4�؁ֵ���UM�ȞX�TY��T��V��X]PlYt�fs�\��ن��ޣo��D�T}�����S���W��_��^�,s��3Q�q+.�a�Z\a����K��a������ȲQDE�{$0�a?s~
�!���S�n%�d"d�v�r5�>����w����s��["�N�����E$Z.�)t���*��'w0A"�������z�a�����t��:�^,�: ���G.V���^��� ^�O,��+`�c@E)���
��>��s4eE��P�D�O�ZQH��T.��rq�;V;���0rḅ>�"�c9���T}��{P�����$V�Բ5��V��Gխ�:v�6�X*�E�WHk�n@%�+����("���f"�=�[m�ddJ�i�.%=�捔����""�?ˈq��)cUs���xf����
/^��iWƒAB�$�7y�Q�� ���/]JL�Qܳ�ʋӂ�.P�� /��KW7�I�(I�l�͗�AY���*�����U��3�����q8���k����:�n���Co��jH��Xi��K�X�dW�7Ds�(N����vU_�5g�&e�������U��T]i��X�"Y�h��t��|��4z�ŕ�L=�k4�B�4���`��7A��2N�%3��iE��^�W��=j����T��oJ�P�)�<��%i��f'���mL�J�Ĥ��«as���n�i,z7���_�����;����T7-C��3Ց}&���2YUw7�i qf�(J\X˲7M�L�%
"Z�6 ��� �ܓ�����&_�	5�UF����5�V�n9�D���+�K��ܼ,����ğC�#�5��E��<����	o9Z�\}oJYjC�p��,�Z������u��>�P%ӗ�	���RHp�$c�D�1�^�x���_��b�+��0C��b����u�+��Ϲ��g�?�r�?�� �jU��^����Id#ax�k�1�k����C�Y�����$;����ːD����^�ir�6R��?@W.���ͽ�x@���b�L��p�7+���v��b3�ʦGa{.���ud4���r�F��� �_1��4 ��j�oyA�
�I��5����J�ͭ�)�	�,˻{������q_zFD�������f��\���GyX����g�p�I��SJ�b"a�
� @H�,E�-��?.|r�3�v�^��P �b��:�Xഌ��
���M�;���{;ȃ7F,l'I�R���/�8�y����`�DU?�K�"�6(Oq�;���Ŀ�(p=Z��@[��f��}����]�Nl3t��S4�4r���V������Tc~��Ȋ��|,)'��e\L�3N^bt{�Z�v���_mT��v�����&���
��Q�b�7�b^���f!�v��M�봥���2��D(�F�ȌE�Y{5��\��=:a+    ���B��C&m\H��B��2�}���Y����7ٕUy��T-�$O�:B���:R���V/@��Axͳ�s�ä[�>��Ig O"
��"͵�;����jV�i#^>;���A��V��1�7˅ n�(w;q��xE-��k�[�s�Bl�򥼞Q^é.�E�Rlċ���w��i9��������0�y �뻝L��m��=�v��3ݧ�Prɂ�JW�m�z:ZZ�ɿ���P�KoyLN�7�}2�6��'/�*�m{�Ggl����`���f�/_)oE���kj)/`�L��w�= �S))�!��M���E�<�Ҍ�G�~�B��`隆2&��=���*�qqFW^k&���ܦ�;�r��P�K`�Ո�~!��Z0a�bf�1��;1ߓ��tkC�N�G@i�S�[�k/���4�;K�ET[9��f����6�kE;C��^�"��ZKY����sV
{�i6?ՙ>�'&�8>ǣ�v ��жʹ�7y_����T�6��5=�l��N/�=���؏�y��QB$B�fc�R)[�Z_�H#�u��)7�n�^i(}��Z�0�oo7mI:�0ܓ�k�@�B���r1գF��X!ƌ'�T��O4���Υ���x�T�(�C.�����E,~�@j�[~���e��#��>c��,�u{8�e\�G��#���@
��Lz"Z�9�Ƌ�~���13�a9�{7J�;]�Ē J�1o��{N`��P��7�U;8ő��#G�TZE�<��˵c��U�V-e1@w��}�		q/!t�n���"��N�J���/�����@��z�(�j�^���]g�,��Ùz�~ihV�Cs���b���`]���%x E?ck�\�##v�p 1'P�fżk]�z����V�>�hx3k�28�q�u~SRU�K��Iƴb�?Y��ۇ�y|�~�le�
��@�n�@��t[����:�JF鰄�L7�~���?D�:�Kqõo�^��}z��H"�ypt���S����!5�3yWkd�$OJ�5�X�]p{��%I���u�&Y�iY�S ���x��f EE�%ȇ��g� ��qX�<���_�6	j��ػZK{;6r��k9�3 [��!�I���`	{��w�pq���V�W��ۜ
z+EK��-P���7^)����z�>P�8{�A�5ړ�X�3L�/�u_��"�fu��C<p�
$ϥ��H�D�)�sxvK����A}*� ��.��U$�xA�Q!�*�ni��l����Ge����8�� b,&�}�__l2��՘�\c�vw�*�1���Ǭ�x�
jPG�m��8n���� =�t(�I���RW�ෆ �c�ר�v�7蚜@�"[�J��hD`t'�G��ڑ6������Ù��6�.��jZOx��W���5O-�]=����F�B8���t�� �TSb<��!�ig��h�� ��h�  *gm{�1ɘ��c~�Ru#;��ea���|M���b|��i��Ƹ���-�k��{v�y������xJ��V�Mcڵ9�!?/�CN���戓�`��X��l��N����u?�:��ם����B�T��P�r�Uu�C�k�n����{���$d�D��w��ٕI����9dC�4b&*�&e.gOaD����E�S�g��Z��Z�ޙ��7Z�)༠D�`�L��G��3��w����;�����u�b��r=mO[}���L��M��Ò�-�W��RF���:���u���[H�.����Կr�R�M�bjC�HP'ت�N/��̩�ǥ����J�0�+��s�6z;MI�O�/'/0tѲ�E�Q�43�����n�SePkkT���T�Đ��oۄo{����x��X6��:|�[�a�H��A4����~�U��*����!� %���N��õ=SҞ?�ٟ�vh>E�>�6�D��c��
?F�ۭH~
�r�/Ĕ3�{~�uu�֬(a&Ђ�bي����u�9ÞcE�%�<��0�?�$C}'~��kPׇIqjK�����#�# P�oՈߦ� ŊM��u�E�]�IS�`0L����#�k<ѱl�u�,7�!ZdH�@a�!_�1z�Wȯv���
~X��R�ŊbЭ�����* ������\Dj��#�Иh�Я׮ �DKO�?N )�^W&{���?0�ns�?rg���?��z���t�3�_'^�	�_ȉ�+Z�Ѭzs�lY���c�m��+`��*�L[�3���$z�|��^�r�V��V��_��4�?��@K}�_����T��@�¬�$O8d�;�o�khm.�t�I���2w̌/���_�C��P%\��>�MVRYW�!Zj	��xH���[Fᅉ��7Zg����W˒琏���{N|0.�؁�W<��v��}��:�/���{����3q�J8�x%��,N^�LPLj��B�95k�'m���^��)�o~8�'�Z���Qa�J���o
_��dY����mS�掰�}%b�I5�{�L-�l���Y����i��j��`�P�j�Z����ޗ ��Ɵ�WN����~l��K��-0���҂hr��It�W�w-��i\%�+y��6I)�<3�)�� �J��\��};�t�mZ���	}��@�I�����b�v��\���F�� P{b kuX�Г��Fs�x��e�;B>bC�ۡ���Qم��w}���^)Zz��I���,�"�����ך���S�;cqN۩t'4j���+� 1�����'(J͒�6�ʫ��N��8��\���^�fDO�{$(X�st���0�ەZ��>[�����+ܫ��N�7"���jBv�s�oz|�墖Ⱥc�$���~�,����&����˲-P8~��P{5��Jr2��H�N�B���A�/���13cF���X>��B��G���Y�k\�R!M>������a��L��z4ُ�K�[v�-��c$ݾ�
ء�s��<���Sb��t��"���"�`�lͰC�:+�[5͖��"C8K�j?�L�D�̄�>��8����/:�wiNz���-2��&>�\)���v���s'4%3̌tPϤO��4���ȯ�C���9:��߭��J�w�3����&��]���ژ�l��Ђ$`����*u#4�;�8.#!���u��]^�GG�$i@����E�6��~�5{��u=�#J_%�Ɛ�ᝤ�N���|%�3`&�͛���zyD���Nt�	�6[������]���5���{����%O�d|::���ɶ:�m���YZ���{��?�l8j�QE*��S.�P� *���h�$T=҂�P��|t1ze�����,%��m,7E/3��k��9/2�) �$����I���cZ�˰9B�Ē��Ѿ.�u�\Ay������f.E�¿.ǉ�1,�I�
N�PH(���Eȼ�5�ԩ���e���67HB��ȺC��]�:�)U����y^ȅ��A�N���I��U�"ha���42$l��u*�&+�5x�{D�^uup@��O�N��n���� a��'��r/���b�B�>��7��tMsܱ`b;�K�Q{�D�
�0���%m�eƺ�^j[�]t�8,��2R�+F��~��ls���p7����?x�V2P
���@8�x�[���x���v�U��i��OC��D�FʏnmwD���p��h�dg�ߤ����p�w��@��dqJ�|��~�nW:#�L�omB+�78Lw�c|���M��/�ؒa��[���+�8����M�2�Mt��DD�P�[�e?�o&	hx"	D؃D��B^|������mD$���y"Ju��<Hз)A'�����Tz
�n�;���k�-���2��[�B-�O��Я�=2[��DzC�xؘӑ,�����`��ë}��Ʉ�� ݄���U�md��I���Q���h����qeO���c��uɥz�R�l2�C��L~vN�;��N�>���}*l�C�%9KB\��뫃���rf<	r=8��U��������� �k2�-�x����x��^F��-�B�
�Q/�Q�I��Ǧ���5\%���e۱��    �&a^��`4���[7Q�pE���1�Z���ċ�'�l��c������!���Z�2x�������c>�q�����]dI�O��A�s�c/�?���wxP1,H�|��"ܲ�7��A�a"�^�"˞�T���wL��.���s��<L�c�c�"V����-Ȫ�:B ���Ѐ̶Iu�?�'��w��%�n�*T5�M1lة-��A!���~P��"�jw��"��]�|M��>/z�����0�-ҵ�/�s��8U$(vj%O�M����#©ޑE��Rn6�$kFVy՚�gko|���Hr�%��)բ�OP����Vt�����ԓ�9�)��tf�	�c�U�7I��hhtޡ�����9�,^���.�&P��ھ4q��q'���
��$]v9�5�F���Oe5���r�x7H	�EiA�ݔ��H�_���^���\�������2��,k;���W�v��Dde����>��er���1ZNҾxP�����ڟ��\��$��4A��b��ğ���0���>J��9j!��Q�瀝��iX����sX��;Y�u��;�ߤFwJ�!�?�C}tg�@� ��B!���J�P;��5���� ŅA�������,'����àÄ>?�Q��� Ц�Y����w1��f��e����ƓiE��X�М�}�-B�$:.%!LH�4+�r{+6���~�F������sA�ځʉG�e�e٠y4���I�t�2o"�3��U/�v�F3�������R�=p�m[���m���jy	s�ҕ��JL���/��K+�^re��|Tl�D\�ӵ"7� Iy�%0L@c4QΜ�\�Bd�-o�-o��4�.G����rۯ��w$���� �\�&2Ĕ�b���>����OD��?������,�vv�Zt�}hT�����ED�hMs�Y�Wj�!p���_�%�a��8i+�>#��۞��BU��c�ٵ����K���g��"}~bPF���.�硺��;k�j����f7
j0��#�5����Y���g9�����¬����lGz{�	��ױI��4@~Tg��Җ�/���K[�M�T���c�ݼ���a�r��(���Q's���h�89s�;����ূA/ڌ9�j�Q�\p�y���	ߖ�Yv���B��p��}��I�Q�b�w�j�j �yz^��GR^���u౽B���qy�*��<�I�����Dȗ��5���EK��	��z��гϋY�ś1a9��'�5�I�!,LKr���R�}c\n)3��$�*���M�;�bI�� J^ߋUfޓ��eG�5@��5���ݤ��N�EY��Y��ʥ��rAd��F�0^X�fe5�݋������x�^����4_���A��P�Ւ�����ܬ�n�CO6;�.�#)��j	�c�qz�������xI��썛���'^�"B����K����KDU�8I2����z�k2=d�������B��z�m��w��qz��]�G=�@���oĸ���e�_Ԃ���R�|\OII�+X͆x����PV���w_/��Yu�%3A{r5̈*W^
�n_:�jmf�����͵�0�N�/���51�d6U�� ��f�<:G�d��H�>�f�m����_i��]�`��"�(*&������P�(�������f��(�?h��[Qi{�2��-�0�))\�$���t�z�//�i�Z�&=-W��Ƕ�o�|�c:D�(l�⫥e��\��*�cj���Ckr�h�&e�G���:z�@w�4"\��=D#�h�ވ���uo�����F��f�P����0��5L�"�b���S]���d\~�`�e���7�7ƴc��c����)��md��{��o�E����jn���"T}!�'�}C���e!��5B܄�$���!W��u�����z�4�fr�{�X���uM�U�n/kA;�&ƙ�������Q4)�M��c�O���	���o��m���¬NQ�~zY6��۔�Hq� q.s����,t�"B�C���rՏ�@�K�ۗ��^��� ȅTC�QGew����,Z:E]�o��孏W�[>��e6�n���ن�{�����Ha��-��-��I�I�����Y��iq�B�ik�ԥ�)�y�#`vk��4����?c����|KzmJF�P���4���@:���2�EO�*�)ѓ\h�P�����Ȫr����x+8z	�.n��	�iR�F���s2ߩ��E����e=����Op��Pߌ<����~�zG�6���e��Z��;_��DFvۂ���h��<[z����.<�x\	C�%���4+p���3�r+OZ4��}"ŗ�rL~J�UV����uC��<��c֒�k�����8!RO`���=J�F庀����,�U���(!�YA<)���	�|X}U�z��ט��H,��+����m���$���v���g�_�Z~���5�}��Q3���5h���������i���������J���8����<�ȟ�ݘ�Ғ�b������L��z�Lq?�{�%V���uH��bKG�!�Z?oGO�2�3��eS�K��x~N��C��\']�.Ϛє([#�~��A�IO���I0+����Ǥh�r� U��.�۞u�%Ew�ɓ�a=��W�ہ��" ��C5�d�M��AF��=����avѵlu�8�Ŏ�Y �-������Xi�sch,?�o�j��LK�f�e��Q*b6bW ���b��|�3,��F}(��n=�����6ũ$��OuQ��P3��W��'������M:�&m��8�%������ʾ�õ��km0�`�5_=���
VӅ[)f���Pƭ��d�K���^�5BE�ҭuI\{")��a��V����J<W�BM6�}9��� U���W-���l-�^g���\-z��G�x��]�*^�xd���NR�m�;�@�^���dݚ ��+by61�nwg:ݔ����6us�pa�s�^��>��bɘ��t�=LJ28�"@+����{�=��^�5(l󯚙o}"�j����k6���pҜa�Xl҆;&�F)�)�h��)M9���G��d������Sp?}�E�1U��Y�'�y�b�ͷ�j@����q�,��443�R�S���'
����m��D!�%��Īď�ِ��h�A$���_-C����)�����v�귩�>#8�+Z�ީ����֊�V�`X� ��O\�[� X/�ZԘ{"U��[{2/������aut#x8�m�I���v�g��y#�їn��g�l�&���ߝ}�V�H"@x/�f볂�H�W�A��l����_ޤe�,=��(��7����E�o�ɗn~A+n�8���>�lu[h�
�ډ�n�߉�T�BB�]��8��ҡ�r���P�r��J�2�[�Nˣ＜�av���NC���D���&������S��J�R�4�:��)"Nԇ�gX T:�N�i��ۦz�����s��V��U���!\�g��;E���)`��дa>ɜ�v�(-T?h�\�U0j�>웨:�#s�M��>n�STM���L�76���ݡ�Q���w˸}�٣�������?6r%'eUecɿ���`�XZj� ����'�������[9UP��wf��|�j&�����Qv}�E��Ï��}�Z%T��d�ekT8�AR6z�p�z�/0��ń<�y߸�kd�Y�}M烿���;���RU���_����͞�w�`��u��n�%�s`��5^��#ԍ�&]
���#��.>>��'�H�<� s�9�o��X��<�8>��w��4V��_q�-���$�;"�D<�J-}�D�>������E��"~A:�Np~>�.���}�H/)ڌ�o#��[�<��oO��X/R�}�$ܩ�%iGo�?X�c�vf׼L-&u�^"]lD� @(���)����KZyK41���vz��+�q��ɚ<�6��뱁�c�~SRY�;��YW�%����߭Du��n���ڣ����3�nQ���Ǯæ���L�:�4���4�=�Kl>    )�>z��-�z�����~���ı���l��fݬ����+�g�V
iÁ�s��S��O�pm!��d��?Pz��*����a��H '�����֛�r�77�3��{*�+�n��D�~kY��Ku�Xw��X�ϒ@u	�L��<�rÅ��f�rЙw����U;q���Dx2�p���Z�P�{�&M��f�8L0T�(My��_��N���.�&H�d�}E�3�"]��ƻ� ݬ�.u�g@:�fx{�$H�J}FD����
���D��`ì�)tvM'�ch('��j��A=�,���W�b������������%|IR�7tv���@qӓ< �w���������WԵ���Z#�$�s�M�|��NW4�n
���4G�ê��&�q/����#�Pۙb��I+�;'�)U�V�έ�"hZ�u�j��ؖ�M�ϿZ|������\�[�韹!M���1�����G��ǡ���h"�E���p��al�S볳5�l��M�5׳�B6��bYʌ ��Xb /j4��jP�~�<���F�v�ʹ����	�����(�R��.p�;ˌ�s�h1��4�8s?z	�=���g)��z��U�3}�1v�b�4����mX�/Le�4t���NOVtH��%����?%�S��8�0,i��S�F[�����JA&,`�6��h�9���s�3��gOx��K�<���}�����\�#y�%�����pDM{��Y{A,J�H��f}�:!��3?x�9f�h�8)��� 	��o�B�a��o1����g�
m�I�J�G:���<��:�G���̞qK�p�2���c���J|3��T%��w�}��ΜثN��1]�2�_/���y!��׳�����Sр�����e�c�]���"�Z�a��%��YI����SН/C�5r�ε�&�@���~xR	f<�;�Z܍�X�헶ľ}}�В,?�����{yѱ�x���xP�gz���̿�WU�%���85a�hu�]�i�n�=��`�l��e�gs�h�r�O]l�	ҙTr�v�5���>�Apdu��}�ZF�����z�ۧb�+	ϫDi�f��Μ�gvZ�:�e�b����/1�Y]tK�GԜ�7�S,{�kjg�E��D�+6w$��Āz����-�a?1�aڋzQ��¡�X�/���-�b�8ՠμb�#Z|c�w���3�f��������ɇl��9� �eg��v��FH�V��]�%��|NN&%�-�u��������p����.�{�MA����F[���b��p�ܯ�����|�9�t��j	t�H����_<�یv�|��(��YƱyS��a��4�!/Ёf���:)��,��1�}+��d���l>�1(�2�����pkd�s5�>�n�<5ӵa���[��i� �mqOm��fO�G=�v��એ�ð%�ה$;�7��y4�S?<�}�+p��Z?�'�L,Hu;h����2�je�Ĝ�M�!��j�6��7Iّ�K]s��S�y��w��YR<l�q~�`+����>����kd��a��MLl�:n@+�@a����^G��afx��ۥ���h�%h�PL��jƇ=�y�$b�>֓�d�7I8�(/�����U,`�r���I�J6�ݫ����%'�����Pyw',f�Z���^�1���8%m��^�����:5s�B����IsgV�3t��ݮ�|�`����Nh-N9�K��w���@#zZ�?�ğ;!Cڥl~�K>>o&%�r�@ͽ�Ւ�����](艁@�н�B�RK��H憺�fL�|KI�������e6�����x�& �_ �LxU��m�� �kjO���i��]�X����X!��\�~��7�|Y�.�e!�!C�W+�0b��P��kß�W�ۢߪp��/,͍�,���괼N�Y�Z����'�Џ�I�8W=�:G��'N��[[�:\�V������M`�mw!C���A�<Y`r�L���U�α`�Z*��^�m'�h�����j�����޺h�U�~���-UST`���U(�B�Mu�CB�=W,�!쨽{��d}S���`��=���f�u���{,7$�[q�TC�o�E.�D��xܥ�}wgL��׋�|�[��e)do���IC���B���*a�|,IqF]��욏�o���W��1�d�>� k�&]�ʼV�����ث~��C{�wb*�>h�����%S��~�sčq��3���`�Kp�{f�� B-��"��
P����@5�����0v\�`�XҜ�OۣE}�
}Xg����b���|�Nm���}���=lV��-Z>�Ҿk��d�˭��^�)C�?Xx�<:j�ǣ��5mKo�L�c��-�|otmI@-~u�#m�IԲ��z�0��b��s	�=k�F���]��>_��S����O<����Oݩ��Nv���K������hI��/���Z�yV_���/��v��˟B����Xu��`wH^��6WԶRI������s_�iC�-�D��߼�@�v���S�x>q�k0$m���'E��O���sj��\���!l]dRo��Ҕ�>�ԛ"<Z�9��N]<!����$����ku��'��h��5~����vp[���H;�ፃ�)%:��1���^�o�Y������;�`3ِ��Y�:;�����i�X����.2��x�pFy���kM=s���lG+���`W8_�+q���.��"y7�z��;�1���P)au�`���$C�M�;�'��ųDM�f�v��(���Dw,�Ş��:���K/w�̷����v�Y�t��g����9^�Df����כ��N��f\�����~��*�@w�h���:������OZ
�ħe&�I�3hf,1$���D��l~Uw.\x���}�5x�kv��3�wcڷ~iY�Q�X�.��UI��+���{�Q2�$�����3�X-?9-/��K�myC<��=�Yv忋�>�����R�mm�!l7�j�Ք-2g�Vi�R̎�nHA���eCY��X3���U���|�S;�9d1��[��i^���(d݉#n!S&_؂d���a�h�f~��7o�ۋ�(��q�'��&���=�p�{�]�x�`����!�.�&��faz>�}�s� }(B��;7�h�O��gۡ߫����>IS=%�3���#m�}�ȷW/�B����ҭa�LL�j]l͕�V(�i��mӪ��x�����Ȣ�z*[c���/<N4�.����#��y"x������l��e�X��{��/��?��cJ�!�ԓ�<�R��&0��Oն��B��Id�w�f���0�^"��ʑra]q�kJe;��P��fp���qgBı�6�z_�G�4�޾�qN>���O�_�)��&xB�g�B�����M�#ޕTU��6�R�F���վ܃�\p.Ú����f0�U+�>�N��&q�N�F�0�j�rdwZ������w������dr�x�o�����2?N}��5<��/�����\�Nr���#���;��:�K�SF ��?B��:nK�ˤ�3�O
�{�>�V�8�%��Y7a�z��[r<>�$���To�x��J��3~������_��T���<o��zL��.I��R�����75`S7��\�����"�����:& �T}�%N72�k�t���!���^���Og��w�U/�p?uy�_�}��Q��ѿL���lg)�\���y#Ӑ�u��s�ԫ�?Ц�t���7ᔉnD?vo��{9}���\����s�x�.6��Ĉ��������t�06��+S��:�LqTE��l�]$�O�?�W�g�%[���|I�vS3�
���#�Rcb��Zd���D���4��L�H�0��ȋ]j�d��^�d��BD�k�-�������h�c��Ame�/g�7�ڙ����M�!���a�Ҕ6tRU[Ajg�ԙ*L��d�$��d��fL�z�/�T��B���v2�y��p�9�.R��'��L��?�W    SꓟSq[��K��^��aD�&cD$z^.��g��,���W��0�jA�UUJ0^(bG9W}�B�qm&�M��yBf�=�x4���Uɤ��H1�i�d���$f�:N�4`�8e����DdȤ��YFiN4p��hl��<�8x}�����	�=Ǧ ���o�[�V�Ś��EY휂��E7��8c�?�Ob�Gܷ^#��h?y<GğL�e�R��<�_�7�ie�VsH���A���I��"A`����	��7��4㯖zL\m_�0�`O��<-	�����3�L�S�L��vuy�hG�^N��k/��D�$iI~+c���2=i<�3H�#��(���ґ����k^Fk�zGU�Lք���c��s���c��`�K�ѧ�!��ݿkϗP/�����E()��&'=B.�]cM��R��@�4��Z�9��u��lQ�+�`�A��v(?�R��pf�Y����n%\�[������6@���t>k��5�kf�e�q�]Sތ��bL->A��h�"�'|��@��_��,�<��jBh�u��[�	�U�
�9�p�ݱ(KG�����Z��I:CIȈ���]l�n�ń"�>-lVu�����8��#ǓS��߯��\>p��7�ʮ�Y��2�W'c�5��Á�HR���&z�ƌ{�>o�A=�=3����~S�)U���X'o*CL>�Ư+�cc��G</�!����B!%2��u��<?��u'{41�|H�j�V�%�<��M,-��>�h��!�(���rMK�t���VEB�QUƒں������::���s�(��1��5��b���1V �f��0'Ƴ�g��p]��W�E?ed"��Oi2�0b�w���mn��m0q�B���d"��6D�s Ie�m�:{SQq*��Q���Xi��W��pIFj�Q<��oȳ�j�Ԙ�����fi������n�4m����%�F�U�D�i�H���������֌1��+�7�Ic�h b���R��6�4+���
�J��l�R/m~�����������Dx;�]eӥ����1V�c���[�}wf�b����b����׉I�V�Rn/VG��5�i��d���wl��¶��eh쌝5D���+c~�^�!9am�6
���1+�$��Q�����/T�`�Ԙ;8�1��9����M��>�CiL������A��oN��<�6�>����/��0��@���'���#jJRhb�l�"�'	�h!5�O������� '8�.i���g���Jx�:�Lw�i��kc
N���!+m&ma�0�ȥ������}F��/�_#Flo(
М��
c�(Nl/����2}`=�W�e��>�f�L"('�p#�P��2Q	 �瘝X��Z�چ)�w�J���a&=��K���~�/��;뇤�g�o��Fv�a�$�����{�m�ķ���A��꽿���/8�������6.�����d;\�ohx>�	�}���0�9���o$=�{�~�v�&�Oi��4�i��7�IG�����Ex�
ᠦ��xw}�+���;�m!�Ge׵ZsJqϋ�q�*�SF�ji*x�Nf6��R�����N�7���s�.�����o!iY��$���.'��A��z���.h�Ij�(���k��2�6��ϘA0��̆G��k�&����X$�C�I���J�BY����Y�V����y��9�����v�Ub5(,��]� `R���c0�����0I���]�l�I�r�r�#{'��P-�J8�K������v=�~�b�.���"_~�:
=QC�Ӌ�BJ6�U��O �%ye����m�_CN�2��T�-�mA�v�(����6m�L_Y�'��W?��8�z�k�Ȕ�L,aƋ�9H���ǀd��H�3_�-Pᬚ)��xtL�'�u~\��_+q9|��W��}�CʞCs̄��n~!�L����}P��1�؜by�cI�����ׂ�� ��3l ��%� ��O=��7`����a�.��,W��@)��b���URt<w��jX�Nn=�`=h��0V�UE��<q0]�v%n��L���:�6����:�d?m�.`2;ܯ�������%�zR�Rmh-���r��7j�l�7��d^��6_N]�B�~K��cA���]��Z��t��b�����	`��=�D�X&��)�Ǝ��OGr���3c�dv����DI�E�ψ�:N���]�8[N�g��,�;���R�����W��P�����Z|�W�bh�L%{�g����X�bۊ�-�Qh2���Z��_"E����6�'څE��<�>+���P�p��0���v��(��2GWo�}�2s�I��4�jWz�D��磇|jQ%7���;��Iy��^��g=�!���Pӝi�df�%[d��ލ��fJ���SX\�}�	@�׵coN�`Z�W�J����*�X�uM�����]��]l��>�x����1lZ�w�<#uFs�cI����_�[�>�9�O�W-�x&lzd*}=;���>�W��n�dw%,�n����:0�\�f��45��&%��+&�46 C�C��B��j3#��v���tg�V�s�_��������!վ�T�> 
[�0S.��������S�:���/r�r��d�&���DAY������a�h��Y�Ń�c>_��R8�7w���2���g`RQ������;`����q�F˦[��87$ĹV��Z�Ո�es�@d�eG�9	���^�}#fo���̞�Z��}�;�/q~[w�A4=�E��T����-��p�
�	ʝ����{u�#��m����>�)� ��$;HvZ��=6!�Y���uC�Z�!8��)N<�|�[�J�K����g��<��ǌ�#R�����U�k������[D�T����۲��"C�E�R�"�tp���W{���m���,IP+�'��ӣ�8����bA�:e���&�c��a��C�/�PJ�����������l3nR���m��4O�bk��֠��η��������8A\�9�Fv�W|O�kӹ�R�S9���b=�g�YomG�m|>1��fסG,���O���#�}[+��{��|�m3�ve�#�/�T7���w��=#�hj�l��x��ǧ��x��b�Ibԅ L���`��w+|[z�e�ݣ7���V��`-A\��1C�R0�Y⯶�/ �&GF�Ҏ�5���U�lHw۫`�8k�#���ï'�Y(N(n���wݤ�D2�iZ+e��]hv�݆�����V�Hu�v��
�&lT�_����pe���>�Ş�� .�{��vŷa�eD��՗�Gr1
���JO4oB1ZF��o� �E ��w�<;����+��htV�<���J�.�d���S3	�NS�f�
V㌠$���)	Ъ]��eT`�^�:a�����LRi+X��]�|�� �ݬH��D�c:��<���f��]�Mo32/�y�4u^�к��"~�W����fT	��U���p��DG|��JZ�E�wR�}��l��P��TM��u���e<	�$��xu�.���V���H���bϫ���fj$�>#
�!����K70?��iY��H�;�>�Ƌ������oM���C���������!nA��n�o#� ����z"��?x.U���������?C)���O9-IٜZ��������W���ښ}��벞�X��3��ܰ��.r�6a��4g�h&Oc�R����\nߠ]�zX�s,oE3_���HQ��6PO�[�z���f�>����M���y�hh�Ζ�S�)����W�e�;R6�d�4ʪ�jƽ2W|ұ��X��Lg�����v	�X��265t���^�z#���Ś�ԉ't������JS�o,He�YM��%�5����	#���'r��"�d9Z/�d�䬐�nJve#U~��aV�~f�O}��>���U�V-J��ڟ#P\T���F��i1���c�c��r��wG�f�^
�ߩ�7۾vb��l���Fۻ�}(c*�VvmZ��Ly�������    
�<#Հ�Uab�B���%^>�������j=w"\L�*���U���|oO���d�I�`��D��c*����;Ҭ!�
Ǵ6 �45|u0��N����k����==^��eO1� 9��N7�r s����E�����H/���	}��K�C�;0�O�A�e��K�uov�4r+d�A��v[�M�C8�'���.vW�B�)���UX�vݟ�������g$/N$�7��8\��͑��zSC܊���܋9@��c�
�k��{�I�W��jPޏ,���F�ד��o\��)��4�~w�˅=W%�*Cs��
����#�b.~��3�������T�Mˤ�.׺�`�+W���S[���ǻ�t�Il�Q?�$�e5�x�H�/Fp�K��0��(��o@��q� �*���b'�Ew���oV1fB�r��/���l�t��lD�Y���{'#p�����1َ96<<���
�U{�;�,����Pm�zt��Q�Ü�9;� e�is\r��\�v&���B�k����@/�xQv��6D:M{B���ҥP����fb�9���;�9U�\�ő�b2f��,��� ȁ�]�Y	R�C���ܺ�CKkͷ܌���m�yLWv��'<#���(�����h���l��hy�i���}m�͌5��o���E�����&������m#V6���C+�k�;:�@��c���b�;x��3�Vϲ��L�/�|0!�{�Y��^�������>�F�5 f>�գ�<k��E ��>�O� ��4_MCNS��t����B#��#�UA��	�rSL�9��\�Z���ZSp�``��[	�VS�,�jВm�p����#�;ԋ������?-��B��FN�DxAbF�M���̚����}�KH�$���ƣ)�I�!xŚo3���}�Z����sA9:♡2��l�H��_��|٘�ZB��#.�׶�X'��W:v��ͦ���MEF�)#�̀	"!�$K��0�}��K�֗������N�뀱ۯ���u�>j����1!��n�^G�V$�M�����yM��ύ��P]l�Jm���M/<��f7f�*0R�Ğո<;��E��~b>_����I��{�ka�.�5�����,%��a��n}��H��;Y�jX�9,�K�M�VNFq���z�#Ym��6�����H
����4l<҇����?�)�J�Ai��y��E�V n�Z<�om��D���ub'�fI�n��u�:y����3����+�� ����P�(��xH�Z�?>d��!�߄��Q|�F=����I|!Z�%�aGz�>f3Wв%0n�6�U�6�G��S{�V)���T�.���|�(e"��)���4�[�6zU�zwvNi=*��Bx��3��²��y���� &�d��a\w���{��/i�������V+P�[����So�l��r*���SM����"���"e�[�`;e$���	e�ƣ�?�@t�IaOu�T���\i��������6�A,��"܅ ���z��[�+&��n����t��^��F2� �L�}��.j&L��b�z֬���mlp��_��N��T���	�'�\��b���Ǖu�W �S=��-�����u�S�"]�T^v|��j8�����>��z�Є���t����c̃9H3[����TM���R�<��m<�h����2 ����Ձ�j�e��ӿ�[GzA�3.�yߢ%�H�RA+w�Oa�����s�z���W��U[�����0��ǘM2�=�y�����[��Z	ޒ ��������?`y�I��kE��j�E�}�0�Q8�s'��b�Z����-��Ǵ��1"�et���dEVn�a�j/��.���}r7G�q.9���Q���hj��x�gz*| �,H�G�Ņ����[�%H0�=��D�� �o�G� ĉ�j�;"�q��\��Fs�j�S@o:k p-��M���mZ��oEpJbN��k_�υ�O����zzީ�����"�cǹ��Qv[/����sj/ݸ�jiKA�V\�$J�0�=,�\��;-��o�w'KL��9}-���⟨ވ;�yq�I"԰ Y�v0lHW�"���f|�y�ƌoV��/^֠�y���+�.�0&Fpc���:��cQ}d����i��ZI���,,�A����]�l�t�C�]dʻ��`)���]Z�?�z����J���S��?��o%Zy�fyp;�+������u�>Zx嵨��	ŏO�h.BZ�.ޖ��+�G Ά�L��giRS8ڱ4z�U6���Cnۣd�s�U���}ݐ��'�q���u�VFV��<�DW����1,a']�*�`��`��K1�V�i�⥰g�c���(�B�A�'[�э{�aC���>Up���P�/�T����>wI�[�&��3F����ߏ��hγ�E������d-�5$�L��5\5��a/Pg�����I��/֭<p �4��^+��k]z*�����]ca�y��ܽ�T��7-&�����$}�+%{a�_�OA�Z��t���E2^$�]�I���fk�Ǣe���[Ab�xi��P �_`g��:�c��+^���Ӏ�A���5���8�2p����n��z�V$�E���-�2~��o(}�ֵ˴l���>�O�_-���Lo���H�Jq��Ϧ�S�k���Ѹ�~QQ$�]���e�,�[���f
���mBɹ��q�;/���0�$;����?��׃�+/�(�k�ǤQk�I �|z-K�Z��7��[��<���X��gY�ڠ�g��!"s���޵��2��R߳��`�H[�#�69�6�9A6��,����q�����j>ƴ�3n��k��Z��븴Y���!nV��r��!e�I����QįmY@�A�u"Aަ|c�����Լo��t[��1���[�G���&�#30����<�t��DW���1ŷO���w�Mj�wK:�۽B��:6<~N����_m�(������~E1��1��s�i��t�en �V0@������@���-��8VT��ߒ�\�k[<c�h0�k�Ҥh�&�Q�L��%��I��~5�:a��f�0	蔩�kU�����z��i$��ݼ8m�%+Y���	�Y"�Uv��Mv]��k�8H���D��2�L�;��9������9I��s�{��$�/��S:�x�_�@�x�?-7�Q��ȥо�W7��"��A�J���1��硰�Zk�Efy���u�U��h�k��B�Jb�iSZ�%Ɨ^7[z yx����?��b���tc�����T���`�c?�O��_<$�D����P��J,�f�En8J�A�L^�&{#rk3�[�\Bt|��V�	�.n�����W��ȳtq7vN�@�}�.�e�1H#�D�#[{�ʠdwzf�s笜S����*�3]P�P[6B5�l��i5��o#�Ԉ`֎p�pұ>T1��s�Iw����ݨf4��S� ~t�f͘�S��夀=�VTܵ�4Ol/ׄ0Q�M{�r��Kp�jtT��0��ПW��0,1���]��-��d|�L;c�Z�Щ��'xY�X;d�#�K���'t�*3_�<��Y��I�]ԑ	��^������b���Ş��;&��<\���U��;�T
�	[7>`�XQ�U⚣�Q��*=,L�*Ar� �m|6�I�`��	���iĮ��-�<:c��8�OS��76��>C���g*pK{`�B��ܵy+���X�h����0��8���Yy��F[�-!,T�{��;0�*y'����T�ψ�ҫd�.Ҳ���a�X�%�K�v3+�êI﫴���u�U�b��Ty�,�L��;^DX�}S
a���$k�hUm���p�/Iߦ�oO3K�5�������o�2�{V-Y�Oa�쉭��0�s�r����vһ_N���e�����]��ae�$�F9)dO3��:��B?̧	&�v(�c��F�eh�^�0�i/C0�Q�K{�����~��f��R^�]�ތ�}���� ��5L1_"�BӘ�L�6Kҽ�� �  ���4��m�{���T��NY�V�}t�:����R��p�,I�aҿ7��Jn�BZ���M��O�������p�����nQ��;�k�Ze�B�"*�^8�ƞm�x�y� 4�b���6�����*�Һ�i�!��&�L�o/������!�P��ϖH�����r�_T��~���D&*-�Y�Ҵ�Ž�y���Sa7��Mqu2���_?}����F9ퟢ( g�S{K��1D��8^�Y�q��c �02Ιb�Q"{�6� ��3	�����t8/|�nWl����{u��}��q�'���&#ƨ����i���mͤ_~�),�w�@��W{��W���h�,vߎa�Y�= i1`�$\�'tI��C��~�� .\�Q��a/p_C$}�k���k臓�!�%���p&��1���q�տ����~e���,+��8�DN�{|�ߡ��q��!�^?-j����b٬��a�O��;L�GrS�k�C�Ew��RZ��W���k��$^&m�5B�3��W�Ե�_���e`9^p*lu΃:a$��7�_�8�E:����nD�����2���v\������3w/{�i��L*'�@�f')읯���B:���{�Nzx�6��J��q������c��l5��E&^��:��ȡoF0}�`��M����Jf9>��|�Ԋ����
�#$�+{�� ��[��9U�A����)�������G���^���f�����@ ��8}����(�<�rO�L����~y�, \&(��Ķ�r�HsW��x���~X��̙=	�k��iZY����k��uݞ|�Ae �$���]�r{��f+>!�J�U�x�*J]���k�:�׃&Bs�qn�+G�����h-��r��1D)<�g*���{��(�OW�Wőq��/�>(���V��ޠ�h������ؠ�O,P��e�[D��0el�1���,v T�-��������{�(����ѴqL�~�0JI�3	���q��N�2���G��+�B��:+�cT�:;�|�m�N��6�دI�@o�{���I)]�ANʙ�� ���q`^����(f��շ�Z�>�� e���X%���^#+��M��h�Oד/����!p|�����|��Ӏ�����Umv���������l.�*�+A�>s ����}z&<��.�*zt2��:ڽWԴP�듟�*���[:�E ������=���cTڋ]��Yf�]O�O
�2�|Pu!�$.x��r*gqL�r�V@1 ����l\���E-��3�24dPE��9�g��?��W5	�g��cZr�-g��w��/ˎ��i7�oB��G�5φ���g��|����cR�z��?>[\i�o��-%!y��u<�5�BH�V��C���ƳMe<C����Їc�|)Ն��48��z���?�Ad�q����n}J ���=m��]���������lZ�qM~Jc�����+,��BZX޴����#bt:���H�������Ţ����L��)TL�?ǚa�2ٙO�rE�e�q@�$����'�b\��Ϲ`m����}���}0�&���L$	�l�+;�i,HkZD�ε10��b�@�y�����ş��WY�N�d���P+��YGa�E����s;�A���$��^Wm���O�i�>�.B��1����/u�]�}�@����H��&x���.��:�-r���D��C&�џ^�vz<^���fO3�Kd'Im��&�ߥ����,�>��������!�]ǲ��C��S�L��m$�r���=K ��'�
��8�$=W�m�e/緻����E�/
ȯ`��q����H�a_i9��/3}=�5��+�UF1+�:Be�'۰�t����j��̘?aԣ+I�S��[By�sm爍��Q��.�G��5���r�}�5���N���	w+I��겗^x��Wn������3�Q p}N�L�G��Z�뿭��ImC��a������"���Z��IP㚐��ilVq
!NqRi��)��i�j}e�Α+6g�D��͇�2�ۯ�i�uh��ڽ�Jc
&�#�����o�4��Z�w�iC�M������L"	V�U��t�AJ�x5�+���\N[�hBny;<�8���	'����-������6jw⥽�;��^�
�����<�j�H��4���c��:�_5׸�J3��mǏ�Iw�@w�0y*}�_�N���OkLQ�X�:���A�=��j�w}�/����G�1@�ND�u�ٝF)6*�L��q�Q���/!ʠ�*N�2B���V򔮅{�-�����;� �����J]ġ��՚:�S���t���J�>�����Uw�*v����e��ǞJn��g�h���Hg��T��e�!=�Ntch��`q�X��m��_d����~l��f����<����&!���C�J(��8K�s"��Fp�
�����7����<\��R,e6Ȼ��b�f�S�5�]���G��c(��_������ӄA?����`��$���+,&�Z�Y�CX]��N<�.sI����׸6���A]��b����	�|����>����4ge��D�Mr�C��+}��gw[Q�s
��(��~y��#��"�nJ4�p���qB���#S�^-��6����OZ�M"�N���i��qo���)ǉAOU��N�m��Q�4)�|�n?U͕{�<�8��y0b��s�ؾ;��"�أ�����޲��?�!KɃ���dO瘸��:-�<P�ehM�iM�3�$?%τS����A���~YDy|=p��eQz��v�=f�"OI�J�͈f��`t(m;-tf�@ƅ�^�z'&%�`�G�?�����,k����1c��ŏ�kC�k��W�թz�'�r�	Z�c	����`�>�f���s�0��GP�$J�m�?��ItJ.Q���L7R��H釙Ƿ<�,�2ތ��w���������� �Ř�      �      x�5�I�$I���}�K���
˺�TGx�Ӹ  ��������ͯ�������~m���vxj����g}���5ϯ�s�[��,��|R�������ޓv�����Ƿ~;�s����<v/?<��uT�5���鿺J����~7?��*�޳��ZY�C�duN�K�(XU8���X5*G�~���_;��f婍�}����c��k���z��Z������m.��w������r��r���:�=����ַ������k����S�}8;�x�ʛ���k���X��&*}�_��W�2/�+�Xޚ�<L?�:��L<^����T.���G8�|�su,=��Nm���:A�қc���ѿ�G���4��q׮'��ܣ�]�\�t%��;c���o��We�U�G���u`�Ё�}b�q[]ܻ�K�z[&	���n�0��y���4��8�~־z�d/&7��_�~B�{5��������S_�mn����y�r	�G��<%@
t��0q-Bĝ�ə��%��I�5qy���'�o����Q��%i�,:�m_���>l����N��T����b�N��0��I�t��HxR?mR�W�$�%7�A�ٟ�Ҭ<_��P9��|Y�A�l�(Q����ݲ��$aM�Ff��Ë�W�>�-x��*|��굄k���}�M��5��%#���[��x��n���;uC\��ʢQ>�!�2̭��g� .69�y�J��vk0�v�znl�o������~G�ȉC<�!�;��$5���>�L0�6��ŷȼ{,{�g�n>�B��^]c�t��\�(A짨Gi�5���ܝ3y� !�5-�~u,�%>�����I�%f���8����D^kd�����ʳx=o�0���IȚ a���#��>p�Y`���j�It�����TZ�fmpڰ51�W%�'�@M�3�C��)?.�y�$���㍮��Z��CCH��2�\�H�2�:���j��.�V�F.�����P4I� GC�<g�l8U|��O7*�T�,s]��&���º ֌ "UK$�ۂeHp�p���{h=�5������w�Y�*:��hr@��n�ԘX�;(�jSv[��c�mk��!/���f��-G�s׌0A��
�"�,t�{X�x� (TҦ]��ebsrc�0Q��H=���ԧ�m�]�� Nl�i�*���
	�w&V�S�t�6�`J�VF]:�`�5ͦX�(~b/jq�*�LB
�-��4�TkE��ƥ�)f����-[�dxs�:b���#y^�y�!=r��%��W�=Ki�}��)<��ǯ�;$��R"]�H������J�ᄶ?��G��Zyz�S�]zB�V1eζ�H�?�X��|�߷���t]�vNU�0�-~ii��&.e��S-�L����0;��
�� R /���6? �􈐜Z紮�^�
E*�����}�[rlQ�3�AqYM9(�T?)~�ktom|���J2�x��_F�����I�&�d���A,.%�8J6('�
�R���ȁ����A�*k��]^��o�U^��Un@T�:�<�`S�X��,e�.�D/ �+�ɾ�>!OQ W:�)���~8�b�I���Ovx1��Ґ���=�����ޣ@@�to5�E�ůj!�A�,n�SP��䢌���gŃ�A����hgN"%�y�������Α����,Rο`�\ؚ��XF���,d���0m޾����*S�)�z����T۾��hs�t5�>��/QK ���l@p[[�_B�-�k���Ҵ��+�,��FṡM�'��g����y�F}�!���9m���rl����o�8%)e�HG3#�<�cQq[ܼ�x�.�Q.��]��ģMR��KT1i�U���!|'Pl�E�W��s�e�j)-�f�SR�U����3�_�	�3�i<����V~y�3֛o2�$�����Wm�kY�玠�P�nB���h��I�nx�H�F,;�&�h���M^���X3"�¡���>L$Q�(�EH���$t*�Hꎏ�z������}�@�|՚�JS�)�بBB�P��]U�xK�a'NSu�ي�fi�-�ҹ�P�2l��}��L�|�?>S�e�+O�;�����5M�Zq	Ϗ�L0����D8O�{Jq���&]�+B�����)��N�����\P�8�X���$5a�d�sL,^0~9�k��h\[l7ɉ ��RŶ�����7mF���d��������2�N������;(����U���IK��d���R�1�/l_��;(��3�vގX
t�ՃVn�
M�R�v����BSD���(�t@]'ㅩؾX#�^3����'�*��!�>Jڳl_:biT�g;Lcy���#^b�S2���C���N?��u�{��&����ے�Noqw�j�%\��V�c;�L��de�ۻi��$��m���)��޷�
�P�7��^�&Q�a(��L�l��8�CT��{�(W������EG���Œ��9��g)�XĹ(4A�E�����z��l�*��M�%��D9��N���ڈrO�)��E+q�͏��A.Z�����<6'�	��T����P;�Z<P���"矆�
��L�0��U���|�.4#��o��)��_��P��l;I�t�QKX�h��M��4:qd�OB'��;�"�ݥ��rwfE�,��shM�33%��ȫ�����埽ɛ��K�A5>�O/��?�:J!:(�X�CV��	(���:����Ǝfq�S��g���I����8��8���ԭ�>vl�cƄX��ke�,�����jRs�Dc�C�H�v-�}��e���w�˷��f�q�=� 9��(�l�=����Ǿ�A����j�����.%���|����X1���i+���v(���ؤ^���8B~�Zsl&2��E^#Hx<<�e�#��Z�xK+�vҒ�7v0-8{�S%�6�C����o�
A���)��|�X�[���Ȱ3J*l���/�0�s`��S3ȁ%�G��$SAQ~ݿE�_�S'�κ���ۖ�f%sl��� �q����}f�%��v���WDl��y2Kp*�%�G:��dF<����!�Fv{袾Hۣ��FFN�/m��l���=z�d&�1m��WQ$:��-�7���o�48J)X�����U����a+�n���b�7����4#X�ri�\2��
qj�>����셬�T�I����*c7���M3�����T�r,�r�����9n}���3x2�ލ;�m����%��C
�>� ��2�v�z��ceq�&���La졧��8iJ�{D�>�:�ۚG��d�ߔҁ�m�퟈�ϟ�\�c�;�rۃ�X�V���E�u�|�R�*]9֙�S(RS3��4ą���?�f<wKf�˜�֝[�Y�iWy��t��i�gV�]D2M���U��>���b[$�SKJ^m���*�8q���(J�F��eF�K�i7��w��҉�g�0�h�����G7��p;�[H�� ʝ���)��qi�S,���4�vdO��;%CL�=��v�x��7�M�b��)��B�VF���G� ��u�˸R��*vf��T��C�p6'IiIN��F꤯�љ�o����Mi��˩c6��"T���L�7�oe.���%��"���m�
o�Fح���d-W�4Yda�\R�E�����l�-漄S�ٝ��tU����86�
��T��7� 33������}��R (��i���8��9ad"�YoϊrI,��N�̋4�U�q�ݍ�6���$q�[8��?w^g�=e�L��vs�;���m��H�+.��7{��Y��21������$]���ά��'A	���oW���Fčp�8����@��@�-c�|�����֭�p��f��i]w�+s�sJ4<�2�=��=��%пe��h�;�m#�xF��.E�p�����RIu���Y7!��9���K����#1 99��Z�u���ִ��Al��-\�som�z��n�w�C�#U�]��g�ʻ���L���{�<�MI @���I���?������1+F���   ;�q	�ڻ���P�<���YD�5���`7�M���s:Y�yE������#c8t�ӣ������.�uGLCܱ���s��PiDH��O����������v.w%�*7u9��=N��.>q�d�� B�
��m�L���k2������r ����=F�}MF���߲q��VpZ�z�ا��a�r�?���ef�mn�,�]�?�U�i�Z�Hq�V��~�Y���fr*��}&vZ��p���������)ì(���@�qY�Js|���2kN��r�J�(8{$�����Sޔു��Pjֽ�L�+�<��c"�X��1�ҽ;�*�+�ԦS��H��Z[ѕ��o<~P�� ��q�4M��%��}�\GU*��f$o��r��:S�+65�|�u��ҁ��h�+��ci���Ç:���ɇ�S!W��2���?vC��W�4j��T"�/��ߪ�+�%�.�!���⸆���UK�3�t�>Cɶ@�l7�TA�� v7rWW��	�"�S���������}��A5V      �      x�U[ɒ�H�<�_�n�g���X{I�N��K-�K��"s"iX�����G.d���ddFFx�G�dٙ�2�&��*�O��l<�}Ͽe�(K>L��:���V7-���ٷq�-�������}�����[:���FErg*������b��I�T�A7ɝ=6f�M����ŷ����ɇ���ִە�Z�����<͒%?��uS��J�yY���9v���l�կL�7��X����ŗn�1�K�����w<��䦪�֖ɳѭ��r\���i�\��!��ei:�����Gi��v6�4�6x��l2J��M�.��5�����h�%-���j�wSuU���X9�$��.�K�Tj��_�ɓo�b�N�7]&W����Yc*���f�u_'�[Uw�x|�8���ͬ�k]��2�i1�oY:Ja�U���5���G����G����5����o�oy��ƚ3تl�����Ov�S�2�ӧ�����ګ�����ޟc+��4�]�E��l��r7T��Eջ�O�,����.�{��w<�1��X��N>�Zux��7�U�|��^z���$����aipNgϲQ6��J�.��G8fg�L���/�7�t��m���e]�Q>N���ZU�ecJmw��������G���LYV�:�B�g<�o�њOg.�m*��'W[���x��x��W�(�{�A�e�mr:�l:�'���V^�_a�/�3�|��7�Е]����F�g��#��fK��<���9.�0��t�OY�Z$�v��^��nkT���z7|��+x��lU�e>*��;�8y�����(���o:��J��&�ȭ騀�,�e�o*����80��(�G�o�ļ+��΄�O&|�����u�mU�B���
����~�0�:��py���-���ڪ�O�:�ck\�<��c�zk4��Z�{�̆�&;�
�����I�[k��ܽM`>������T�1I��4��Cu-��?V�|�%w���Y�m���f�	�R�p�E���-u9$�ږ��ůG"`Bۨ�K^��F;Gs��e:�vht�_I�y{�$s��A���'w�bZ�?�G�C[h�S�i��Ģ��?��G�lt0��;M�XW�`��Zɝ.,i��4�;�K�����i��3��d�5��lL��ܝ'�Zik!�+����4M��B*yT�;g1��8�o��*�L@��N���C��p�����1�½ϝ�L�u�Hx7�,��&DvFǧ�1L�)�6��{�����_��3~4#�7p�+�LvJ-�l4K�[�y�۵��G���	��,�=>�	BȢ��,������=8G�|z�d4+���ܻn�~e|Bt���1ܗ��J,���O�n6�$��z�͈͛M�������2x���h6�A�r.���V�3����,�F `ۣ��X�t<���%C!�k��
�;Oy._ ���\���f,�4ͳ�]���	��!�+ލc��ɵ�7�j�� ���;+�{4�������Q�������|��i;����u�?'7������4 ec��F!���g8=$�7M���A5��� �{��[��=`�a9]�[.������h1���U�ݱ�~z���)iE�K���x�Oo�)!b��}}~2dKC���c���-�z���A|z��bN8]Ȱ�ހw�`�b�@��ή�kD<᧿{AP]L�����f�'7� �fx�ґ6��'��$�Ͷ��ځr*���.ɵ�-� |YV��lo<��6Bxt]Y}��s&�t�
_�۽��6k�����W�����ɜ��Qm׷���V�e�����Zm�6���9EtF�N�� 7-��z���x�x��*A�_�Н�c.����Az�~�֪��������~E���K��C΋,��d	�[o;!AR2����"�l���v�\P���N3s�x�n�ͦ������/�S�9Q��ʣ��"���q(H��P,�҈Y�!�#f������u��=Z{�9�
a�돺�=!���@#��OѶ��;����qm�b.���)�e!����x�rk�.r�T0�2���J�→�o��S�kې��û��jF�HwI`k"�PH���J��Vպ��a2�۩Ca�K�t��3�R+��TQ�60�i8T��'k�7���-�9��,H�G�|(�R�4+a(�g��|�N�����jEzlEY;V"8�B0܃KQf$!+�"�F�B2<�?x�j���lwc> Ѣȥ2h��!hD*��8��B�k���񂠕s�?T�?1�j��:��{\g���8�Z�$E���^y�܏��,� y�qD���%�?�6�SG�m*;hC�@A�Yh��L��;��Q�����֭��W]Va��ř9?�����2S
)qo��\�mL�s��5�	OPa��Z#?��_枑�@`�K��� ��@Rx~�L��!ho� @���b��6��q�k-���s��kك0���� @�M[�}̠t> �H���C���^�'n��d	�|o�z�Y�DwSN�`5[W���}���BU@�W ��7p*䊡]�!�$) J7���8������S4϶=O��߄$z5$�9�%l��i�Qs��E�kZ_�Ń�Bi�I�n��[��#����2�jx*@rD��wUB���.�FD#���Zj[��h��1� rcoFh�b�H�Co� Mh����+*TusO�RH�k��k����y�T�����B�^ҟ��S�=ط�>n�c����Duʔ����=S����Bx��4��)�(
	f\�^�k��;U129bh��ޝߛ�Wj��PT\
�qgK�I�����di�
�t#���Y"w�qS�|HT#V^<�db]H<�k���O���yz�4�\����?�#�C{�=B�D5�A
��R�/ahu���̥$#H�X$+��[��5>c#\?�/*�࿣���Syh�#)�� ,wՕΈ�	k�~��BB���1�e_	�=�c`a�K���O�Eޙ$@s �8���X������+!���������%��Y�ϼHH!5^��@��U��§r��W�?	io���IJ}aX�v�öbi'$n���2$�������,Ն�f�vRK�&�Q 8�
Z�������v{t���qG�}Xw,|E.��0�J� �}��U`�Y'��Gj�e�µ:j�{�Bw�J*Q���N�p�be�vWW=\�#�T�������Ֆe?�3 E�����sP�{����l&����=��b�?�]�����~�,��[�J�W�e�+�g�1,P���jSWG��hd��	�U2�I-����w�:0�nc�*�}JHΠ<��1� �j����W�P|��J�Z�\^·O��K�W�z�/"�\j�cf]!w��i��ǥO�񬹪��D�7�:^N�5�/ؕ }���џ����YUX8-5d�
��Z���e���Z��3H���4Ѕ�z-qR���_�-5d���׳E�*�������a%�&���ge�拌3��cw%�"��	�	���<Ȕ�lM��vU�_�������fo�ܫ�>�ɝ3t�Ǡ:�~:�����|b�぀X���ۑ���`3(��1xאE���+�zʺ'R�Ŧ�&tT�sײ�Џ�n�Y��f�!o䧆U�P�,�&A�lV]�>?mO���N��+H��3eTP�l�7T���mU<~Aʌ
��\b�C�w�2H�->WL�"!,�K��<��s��7� B~A+x��$锈�*�f5�Z��ۈ��8 }X�$kK!q�RR��Y�<��-���� f �Y�e" ��8�Z4������&̧�)�j�S3F���d�r����ئ�:��1� C��ް9t�ـ�Y�@��� !A.� v{�l�����9b�
.���!e*.	�R$��s�%�	����a�K���X�`pB{8F�%�7V/挫��G+6��(�������]A��,�(�����5�Φ�#�+�c�(։��FuUl�ƭln�F�4 "  ��S��{�(��;��'���m'�;8�����i._9�&Rw�Ö߻r�S����>^5���靬/�,9^H�7+��Nd=m�0�Aw�`���uعb��Ih��'X<���n;A�Pj�^@�qoY��`�������\�@��%���X/K*���d��^��S�c��`XZ����t�]�(���� �dc����p�����Q��*2��/�f�x���ߪ}L�S	%J��Tl$v&*�Hd�W8{��=�T���X��]��>@���<��
��P�^uc	��T�ٔ͢���fﰗ�{�Yd���\�����_�T����u�����R�i}WYSǜU�[�EX�ŉ?�c(/ys�3vt	X���n�Z2B���l}l��ݝ�/�d�"o=%+��0Vǔ��.�GH���*۶QP8�A�@�jr�:��\3�yjdy�u˅��.��$,	�!��nJ_K��: G�s�|�o�����������l�S���v(֦+��j�R,���
l�8/��n��>����L�v�`��T'��ze"] ��ǖ7-��A�< �����	Ŋ��e�I�P�a���l`"�}rm�/$mw�v�k�¾P)A���b�2���:�;�KՒK��Ay8���H'M�VH��m��O_r�M�ҩ�f9�ޔ!�R�M�`��kC;E\w�
��P��;�B�/}�Ե��'2� E�}��cbeY�ɑ�����!�N���n�ҹ�o�@�@��Q ^d� Ӑ��jX0+�lO�6��&^fQZB�lj��|�8D	�rk@&oY�1���k9$ɛ�fE;H���Φo#��{���bz���2� M�o�W]�������χBY�Rq2ƕ@rHFޚN�N�S}��/����D�ĥj���^e�T�Cua�%������s�hC��5��x��ia<�J@�{�;ueb����H #(��M���L��#�
j���=�i<�yО�5U�Ү�C�<(����©tgA��S@u�&�5Bw�e���{�i�R�/xf�^	�
��mee&�L��a�z���"�o},���!?(��[��p�{��C~ ��3~��W��\Z���
�ߕ(M����MT��!c�i�2'TQ�q�q�$�8	TI�l�����N��q�D��񲲃nc�N�Kp޷�Fb���r�:0ɿ����y�[�N	�-�&gcD5k�W��݇z���!I���A�p�Ҿ���$Y{u��9K	9ǧ������F�ڦ�\��9���T���匽�q��b�Uq���͊V��'e���D�?�ήZ��?�W��ErKAa�z����&�-�t��W��w2]���g��R�=q"��5�;y��v�.��"�
�!�+9�WG���9� �K��$�]���A�/�H���ɪ/�>)YG^��}ucu?O)�Sb)c�c�<��g����A��PjI�\T�1��,|� ����F��[�un:$��m�f����H�V��]�v�4]i��BH�9��YG�3���~d�ˡ������%�T����[���C���/��z�0�f8�j����.7_�^ZIBM�t�9���x��H%�!EY��������#�� Dǰ�R�c*��� ,Vm��8�*y�dr2/ueb���"�����bEr&c�� �
���i��Գ��C�\0�Y�ӧ>�B�&�%+��1�v����i�+�q���q]��B��B�H)U�����Rlsȏ[[�au޶g�I\�oq�ʓ��F&S�X��C������o(�I���h⪥R��S[�������� >��e�՗���nΌӒ3�X�
��P��'���w5�$]���Y}p�/�|*÷�&����g��Hy@3��ݤ���C}����xO(��a� �a�~+���J*;˝\��o�G����)�*aE���P�w)j&�k�(y��XP&F��LJ_����f~�%g+��DP�c�c٪�c9�!��_0���Y*�,�1,�G�)�PǔJb��VPM}G�\�$����xc��4C*�<cs�Ͱ��6����!<^�q"V.u����~R����U�������D����A�����:	���-��
�ߔ�^��J���(=N߂箷>W���T��?�������sڡ?q�������@���ҡ�e
�s��j����󘻛�О| v�&�2�TqsH����$R����?��(���t�
���@�nL��g㍰��Wi6ёi� �]t/X9���έ����bh�Q	 �݅���w�sh���G��Z��Z�`�X����wd_l���#��Īف�k��n �����Uqzm�-�X����I��6u�-��	K��i���+��b<�������ё�I�����>��<U��S@y�4,�Wf��qHÕ��ȏ�z��L�al5�c�-y��(i�K+71S@y ܌��C��5�,]C}\c׬�pJ�$�f�r���?���g_��H��s�f�������
*i��;��϶'��$}ev�_���A�̫�"��(�ˬ�y���gn��چHZ������3,���3���(�=r�C� �c�Nh��i����!� ���8y�F�:��=Tz��:ǃ�x�Az���mN�`Rs+�;��h�}��o�ۡEF��hL߮9���Tm��@r�)țm�xc
��Q�)����ģ��et��a���ZE��
�ǫ^qca�-�LF�����Q�4A����4:4�%_�2�N���l�t9�d�h�"�x�C��U������r�]��{��O-�zc�+�Pq���w&r#�",�;.+%#�e()�3q���2�J��.U8 WMDp����LI�����c�Y#i?iNf;�����x�JR���IsOj
����8����j�n���� �8��HEF���<.91EZ�v��N���Y'M+l�6F-w��AY�?������I��7��2����h
~�!��7C�j����(фWD�!�.�	��n��Z�9���S
h�$s��.Y�`F�P�IU�`��v='{��4����Zە�z��k��T,�C��O�׭�7��i^�9[^ʐ�z�����X���1hid��Ky�f����u�|0WL��Kr�.��<1	C��n���Z�{D�:�n���i�N����ހ}�3�[���zJv{ؑ��C�S�\$�>����t��@�7[��,�O9�8R�邿N�5��G4����|ͧ���Ii������xw�o=�m�7p}���<Ng�)���T]���� ������෾�5�s�E�p����:C��=*d�J*��C#����6���?|[�m��q g~���W�6v,R�xh1;U���0/7���B�b��[���~ɇ���&��b����O�}�F�>�XO%�Ϧ����&@&t>���F�fua��W�S��Q\��2
2H�=�_swu�A���t�9�-�U#3����Kݔlnޙ
�f?=�fN��ݶ� S�����'��X���y�D��=̲���j����)�9�-{M��y�<��ny������!ll�*�V�>�pj�����.��T� ՚P1��-ܐ��f�,��CSЩù���za��!X@s��K�wl��ΦK\�At\�}�F���~K鬀���hoݪ*.���Eq^v��5O�b��|��OBݿ�����Ɨ3[�2��4�{ZK������I�>q�q�|�B �p����5.fAS��AH����N�B�� �����*I����h���3�:     