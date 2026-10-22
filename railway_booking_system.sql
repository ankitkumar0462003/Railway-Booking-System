-- =====================================================
-- SMART RAILWAY TICKET BOOKING SYSTEM
-- Oracle SQL + PL/SQL Mini Project
-- =====================================================

SET SERVEROUTPUT ON;

-- =====================================================
-- 1. DROP OLD TABLES
-- =====================================================

BEGIN
    FOR t IN (
        SELECT table_name
        FROM user_tables
        WHERE table_name IN
        ('BOOKING_AUDIT','PAYMENT','BOOKING','TRAIN','PASSENGER')
    )
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name ||
                          ' CASCADE CONSTRAINTS';
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

-- =====================================================
-- 2. TABLES
-- =====================================================

CREATE TABLE passenger (
    passenger_id   NUMBER PRIMARY KEY,
    passenger_name VARCHAR2(100) NOT NULL,
    age            NUMBER(3),
    gender         VARCHAR2(10),
    phone          VARCHAR2(15)
);

CREATE TABLE train (
    train_id        NUMBER PRIMARY KEY,
    train_name      VARCHAR2(100) NOT NULL,
    source          VARCHAR2(50),
    destination     VARCHAR2(50),
    total_seats     NUMBER NOT NULL,
    available_seats NUMBER NOT NULL,
    fare_per_seat   NUMBER(10,2) NOT NULL
);

CREATE TABLE booking (
    booking_id      NUMBER PRIMARY KEY,
    passenger_id    NUMBER NOT NULL,
    train_id        NUMBER NOT NULL,
    journey_date    DATE NOT NULL,
    booking_date    DATE DEFAULT SYSDATE,
    number_of_seats NUMBER NOT NULL,
    total_fare      NUMBER(10,2) NOT NULL,
    booking_status  VARCHAR2(10) DEFAULT 'CONFIRMED',

    CONSTRAINT fk_booking_passenger
        FOREIGN KEY (passenger_id)
        REFERENCES passenger(passenger_id),

    CONSTRAINT fk_booking_train
        FOREIGN KEY (train_id)
        REFERENCES train(train_id),

    CONSTRAINT chk_booking_status
        CHECK (booking_status IN ('CONFIRMED','CANCELLED')),

    CONSTRAINT chk_seats
        CHECK (number_of_seats > 0)
);

CREATE TABLE payment (
    payment_id     NUMBER PRIMARY KEY,
    booking_id     NUMBER NOT NULL,
    amount         NUMBER(10,2) NOT NULL,
    payment_date   DATE DEFAULT SYSDATE,
    payment_status VARCHAR2(10),

    FOREIGN KEY (booking_id)
        REFERENCES booking(booking_id),

    CHECK (payment_status IN ('PAID','PENDING'))
);

CREATE TABLE booking_audit (
    audit_id     NUMBER PRIMARY KEY,
    booking_id   NUMBER,
    old_status   VARCHAR2(10),
    new_status   VARCHAR2(10),
    changed_date DATE DEFAULT SYSDATE
);

-- =====================================================
-- 3. SEQUENCES
-- =====================================================

CREATE SEQUENCE passenger_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE train_seq     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE booking_seq   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE payment_seq   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE audit_seq     START WITH 1 INCREMENT BY 1;

-- =====================================================
-- 4. SAMPLE DATA
-- =====================================================

INSERT INTO passenger VALUES
(passenger_seq.NEXTVAL, 'Amit Sharma', 28, 'Male', '9876543210');

INSERT INTO passenger VALUES
(passenger_seq.NEXTVAL, 'Priya Verma', 24, 'Female', '9876543211');

INSERT INTO passenger VALUES
(passenger_seq.NEXTVAL, 'Rohan Singh', 35, 'Male', '9876543212');

INSERT INTO passenger VALUES
(passenger_seq.NEXTVAL, 'Sneha Patel', 30, 'Female', '9876543213');

INSERT INTO passenger VALUES
(passenger_seq.NEXTVAL, 'Karan Mehta', 22, 'Male', '9876543214');


INSERT INTO train VALUES
(train_seq.NEXTVAL, 'Shatabdi Express',
 'Delhi', 'Bhopal', 50, 50, 500);

INSERT INTO train VALUES
(train_seq.NEXTVAL, 'Rajdhani Express',
 'Delhi', 'Mumbai', 60, 60, 800);

INSERT INTO train VALUES
(train_seq.NEXTVAL, 'Vande Bharat Express',
 'Delhi', 'Varanasi', 40, 40, 1200);

INSERT INTO train VALUES
(train_seq.NEXTVAL, 'Duronto Express',
 'Mumbai', 'Kolkata', 55, 55, 900);

COMMIT;

-- =====================================================
-- 5. FUNCTION: CHECK AVAILABLE SEATS
-- =====================================================

CREATE OR REPLACE FUNCTION check_available_seats (
    p_train_id NUMBER
)
RETURN NUMBER
IS
    v_seats NUMBER;
BEGIN
    SELECT available_seats
    INTO v_seats
    FROM train
    WHERE train_id = p_train_id;

    RETURN v_seats;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Train not found');
END;
/

-- =====================================================
-- 6. FUNCTION: CALCULATE FARE
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_fare (
    p_train_id NUMBER,
    p_seats NUMBER
)
RETURN NUMBER
IS
    v_fare NUMBER;
BEGIN
    SELECT fare_per_seat
    INTO v_fare
    FROM train
    WHERE train_id = p_train_id;

    RETURN v_fare * p_seats;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Train not found');
END;
/

-- =====================================================
-- 7. PROCEDURE: BOOK TICKET
-- =====================================================

CREATE OR REPLACE PROCEDURE book_ticket (
    p_passenger_id NUMBER,
    p_train_id NUMBER,
    p_journey_date DATE,
    p_seats NUMBER
)
IS
    v_available NUMBER;
    v_fare      NUMBER;
    v_booking   NUMBER;
    v_count     NUMBER;
BEGIN

    -- Check passenger
    SELECT COUNT(*)
    INTO v_count
    FROM passenger
    WHERE passenger_id = p_passenger_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Passenger not found');
    END IF;

    -- Check journey date
    IF p_journey_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Journey date cannot be in the past');
    END IF;

    -- Check number of seats
    IF p_seats <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Number of seats must be greater than 0');
    END IF;

    -- Check available seats
    v_available := check_available_seats(p_train_id);

    IF v_available < p_seats THEN
        RAISE_APPLICATION_ERROR(-20006, 'Not enough seats available');
    END IF;

    -- Calculate fare
    v_fare := calculate_fare(p_train_id, p_seats);

    -- Generate booking ID
    v_booking := booking_seq.NEXTVAL;

    INSERT INTO booking
    VALUES (
        v_booking,
        p_passenger_id,
        p_train_id,
        p_journey_date,
        SYSDATE,
        p_seats,
        v_fare,
        'CONFIRMED'
    );

    -- Reduce available seats
    UPDATE train
    SET available_seats = available_seats - p_seats
    WHERE train_id = p_train_id;

    DBMS_OUTPUT.PUT_LINE(
        'Booking Successful!'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Booking ID: ' || v_booking
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total Fare: Rs.' || v_fare
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- =====================================================
-- 8. PROCEDURE: CANCEL TICKET
-- =====================================================

CREATE OR REPLACE PROCEDURE cancel_ticket (
    p_booking_id NUMBER
)
IS
    v_status booking.booking_status%TYPE;
    v_train  booking.train_id%TYPE;
    v_seats  booking.number_of_seats%TYPE;
BEGIN

    SELECT booking_status,
           train_id,
           number_of_seats
    INTO v_status,
         v_train,
         v_seats
    FROM booking
    WHERE booking_id = p_booking_id;

    IF v_status = 'CANCELLED' THEN
        RAISE_APPLICATION_ERROR(
            -20007,
            'Ticket already cancelled'
        );
    END IF;

    UPDATE booking
    SET booking_status = 'CANCELLED'
    WHERE booking_id = p_booking_id;

    UPDATE train
    SET available_seats = available_seats + v_seats
    WHERE train_id = v_train;

    DBMS_OUTPUT.PUT_LINE(
        'Ticket cancelled successfully'
    );

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Booking not found');

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- =====================================================
-- 9. TRIGGER: BOOKING AUDIT
-- =====================================================

CREATE OR REPLACE TRIGGER booking_audit_trigger
AFTER UPDATE OF booking_status ON booking
FOR EACH ROW
BEGIN

    IF :OLD.booking_status <> :NEW.booking_status THEN

        INSERT INTO booking_audit
        VALUES (
            audit_seq.NEXTVAL,
            :OLD.booking_id,
            :OLD.booking_status,
            :NEW.booking_status,
            SYSDATE
        );

    END IF;

END;
/

-- =====================================================
-- 10. CURSOR: DISPLAY CONFIRMED BOOKINGS
-- =====================================================

DECLARE

    CURSOR c_bookings IS
        SELECT b.booking_id,
               p.passenger_name,
               t.train_name,
               b.number_of_seats,
               b.total_fare
        FROM booking b
        JOIN passenger p
            ON b.passenger_id = p.passenger_id
        JOIN train t
            ON b.train_id = t.train_id
        WHERE b.booking_status = 'CONFIRMED';

BEGIN

    DBMS_OUTPUT.PUT_LINE(
        '===== CONFIRMED BOOKINGS ====='
    );

    FOR r IN c_bookings LOOP

        DBMS_OUTPUT.PUT_LINE(
            'Booking: ' || r.booking_id ||
            ' | Passenger: ' || r.passenger_name ||
            ' | Train: ' || r.train_name ||
            ' | Seats: ' || r.number_of_seats ||
            ' | Fare: Rs.' || r.total_fare
        );

    END LOOP;

END;
/

-- =====================================================
-- 11. BASIC QUERIES
-- =====================================================

-- All trains
SELECT * FROM train;

-- All passengers
SELECT * FROM passenger;

-- All bookings
SELECT * FROM booking;

-- Available seats
SELECT train_name, available_seats
FROM train;

-- Confirmed bookings
SELECT * FROM booking
WHERE booking_status = 'CONFIRMED';

-- Booking details
SELECT b.booking_id,
       p.passenger_name,
       t.train_name,
       t.source,
       t.destination,
       b.number_of_seats,
       b.total_fare,
       b.booking_status
FROM booking b
JOIN passenger p
ON b.passenger_id = p.passenger_id
JOIN train t
ON b.train_id = t.train_id;

-- =====================================================
-- 12. TESTING
-- =====================================================

-- Test 1: Successful booking
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        '===== TEST 1: BOOKING ====='
    );

    book_ticket(
        4,
        3,
        SYSDATE + 15,
        2
    );
END;
/

-- Test 2: Not enough seats
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        '===== TEST 2: NOT ENOUGH SEATS ====='
    );

    book_ticket(
        5,
        3,
        SYSDATE + 15,
        100
    );
END;
/

-- Test 3: Cancellation
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        '===== TEST 3: CANCELLATION ====='
    );

    cancel_ticket(1);
END;
/

-- Test 4: Invalid booking
BEGIN
    DBMS_OUTPUT.PUT_LINE(
        '===== TEST 4: INVALID BOOKING ====='
    );

    cancel_ticket(9999);
END;
/

-- =====================================================
-- 13. AUDIT RESULT
-- =====================================================

SELECT *
FROM booking_audit;