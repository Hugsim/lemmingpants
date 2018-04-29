SET SCHEMA 'api';

CREATE TABLE agenda_item (
    id         SERIAL PRIMARY KEY,
    supertitle TEXT,
    title      TEXT NOT NULL,
    order_     SERIAL,
    state      state DEFAULT 'init' NOT NULL
);
-- Only one agenda item may be active at the time.
CREATE UNIQUE INDEX ON agenda_item (state) WHERE state='active';

GRANT SELECT ON agenda_item TO admin_user, web_anon;
GRANT UPDATE ON agenda_item TO admin_user;
GRANT REFERENCES ON agenda_item TO admin_user;

GRANT INSERT ON agenda_item TO lemmingpants;
GRANT ALL PRIVILEGES ON SEQUENCE agenda_item_id_seq TO lemmingpants;
GRANT ALL PRIVILEGES ON SEQUENCE agenda_item_order__seq TO lemmingpants;

-- Returns the id of the new current agenda item if things worked out well, 0 otherwise.
CREATE FUNCTION set_current_agenda_item(id INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
    AS $$
    DECLARE
        n INTEGER = 0;
    BEGIN
        IF EXISTS(SELECT 1 FROM agenda_item WHERE agenda_item.id=set_current_agenda_item.id) THEN
            UPDATE agenda_item SET state='done' WHERE state='active';
            UPDATE agenda_item SET state='active' WHERE agenda_item.id=set_current_agenda_item.id RETURNING agenda_item.id INTO n;
            RETURN n;
        ELSE
            RETURN 0;
        END IF;
    END
    $$;

REVOKE ALL ON FUNCTION set_current_agenda_item(id INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_current_agenda_item(id INTEGER) TO admin_user;

CREATE TRIGGER agenda_item_news
    AFTER INSERT OR UPDATE ON agenda_item
    FOR EACH ROW
    EXECUTE PROCEDURE websocket_news();
