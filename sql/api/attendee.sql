SET SCHEMA 'api';

CREATE VIEW attendee AS
    SELECT * FROM model.attendee;

GRANT SELECT ON attendee TO read_access;

CREATE VIEW attendee_number AS
    SELECT * FROM model.attendee_number;

GRANT SELECT ON attendee_number TO read_access;

CREATE FUNCTION create_attendee(id INTEGER, cid TEXT, name TEXT, nick TEXT DEFAULT NULL) RETURNS api.jwt_token
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = model, public, pg_temp
  AS $$
  DECLARE
    aid INTEGER;
    result api.jwt_token;
  BEGIN
    SELECT attendee.id INTO aid FROM attendee WHERE attendee.cid = LOWER(create_attendee.cid);
    IF aid IS NULL THEN
        INSERT INTO attendee(cid, name, nick)
        VALUES (LOWER(create_attendee.cid), create_attendee.name, create_attendee.nick)
        RETURNING attendee.id INTO aid;
    END IF;
    INSERT INTO attendee_number(id, attendee_id) VALUES (create_attendee.id, aid);

    -- Lets create a token and return that to the user.
    SELECT sign(json_build_object(
            'role', 'authorized_attendee',
            'exp', extract(EPOCH FROM NOW())::INTEGER + 86400,
            'mode', 'r',
            'lp-aid', aid -- the attendee id properly namespaced. :D
        ), current_setting('app.jwt_secret'))
    AS token
    INTO result;

    RETURN result;
  END
  $$;
REVOKE ALL ON FUNCTION create_attendee(INTEGER, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_attendee(INTEGER, TEXT, TEXT, TEXT) TO read_access;
