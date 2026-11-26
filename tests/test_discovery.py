"""Offline four-device discovery and duplicate enrollment tests."""
import contextlib, io, json, pathlib, sys, tempfile, unittest
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"macos"))
import discovery

class CapacityTests(unittest.TestCase):
    def test_four_distinct_devices(self):
        slots=[dict(serial=f"TEST{i}",address=f"10.0.0.{i}:5555",eye="Left") for i in range(1,5)]
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp)
            (root/"settings.json").write_text(json.dumps(slots))
            def info(addr):
                return next((dict(serial=s["serial"],address=addr,model="Quest 3S",w=3664,h=1920,override="") for s in slots if s["address"]==addr),None)
            with patch.object(discovery,"ROOT",root),patch.object(discovery,"devices",return_value={s["address"]:"device" for s in slots}),patch.object(discovery,"info",side_effect=info):
                buf=io.StringIO()
                with contextlib.redirect_stdout(buf): discovery.discover()
                found=json.loads(buf.getvalue())["found"]
                self.assertEqual({x["serial"] for x in found},{x["serial"] for x in slots})
                self.assertEqual(len(found),4)

    def test_duplicate_registration_rejected(self):
        d=dict(serial="TEST2",address="USB1",model="Quest 3S",w=3664,h=1920,override="")
        with patch.object(discovery,"devices",return_value={"USB1":"device"}),patch.object(discovery,"info",return_value=d):
            with self.assertRaises(RuntimeError): discovery.usb("",["TEST1","TEST2","TEST3"])

if __name__=="__main__": unittest.main()
