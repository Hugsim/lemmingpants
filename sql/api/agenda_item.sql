SET SCHEMA 'api';

CREATE VIEW agenda_item AS
    SELECT * FROM model.agenda_item;

GRANT SELECT ON agenda_item TO read_access;

-- Returns the id of the new current agenda item if things worked out well, 0 otherwise.
CREATE FUNCTION set_current_agenda_item(id INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = model, public, pg_temp
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

REVOKE ALL ON FUNCTION set_current_agenda_item(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION set_current_agenda_item(id INTEGER) TO admin_user;
