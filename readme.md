# reExecute

Persistent startup execution for reMarkable Paper Pro Move.

reExecute uses the persistent MDM agent config to run a user-editable hook from `/home/root` after boot, without relying on systemd unit files surviving reboot.

## How it works

The MDM agent reads:

```text
/home/root/.local/share/remarkable/mdm/mdm-agent.toml
````

reExecute changes:

```toml
user_auth_cli = "user-authenticator-cli"
```

to:

```toml
user_auth_cli = "/home/root/bin/reexecute-user-authenticator-cli"
```

The wrapper logs the call, starts your hook in the background, then immediately forwards to the real `/usr/bin/user-authenticator-cli`.

## Install

Connect the tablet over USB.

```bash
chmod +x install.sh
./install.sh
```

The installer prompts for the root SSH password and connects to:

```text
root@10.11.99.1
```

## Edit your startup hook

On the tablet:

```sh
vi /home/root/bin/reexecute-hook.sh
```

That file persists across reboot.

## Logs

```sh
cat /home/root/reexecute-wrapper.log
cat /home/root/reexecute-hook.log
```

## Uninstall

Restore the backup config:

```sh
cp /home/root/.local/share/remarkable/mdm/mdm-agent.toml.reexecute.bak \
   /home/root/.local/share/remarkable/mdm/mdm-agent.toml

systemctl restart mdm-agent.service
```

## Warning

This is a hack. Keep your hook non-blocking. Do not put long-running foreground commands in it.

